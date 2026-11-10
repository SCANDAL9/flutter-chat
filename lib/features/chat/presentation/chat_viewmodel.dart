import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../schema/data/schema_repository.dart';
import '../../schema/domain/entity_descriptor.dart';
import '../../nlu/logic/dialog_state_machine.dart';
import '../../audio/data/vosk_audio_service.dart';
import '../../audio/data/tts_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class ChatViewModel extends ChangeNotifier {
  final SchemaRepository schemaRepo;
  final VoskAudioService audioService;
  final TtsService ttsService;

  List<EntityDescriptor> entities = [];
  DialogStateMachine? stateMachine;
  final List<ChatMessage> messages = [];

  bool isLoading = false;
  bool isListening = false;
  bool isVoiceLiveMode = true; // Voice-first priority (Gemini Live style)
  bool isAssistantSpeaking = false;
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String statusMessage = "Iniciando...";
  String currentPartialSpeech = "";
  String lastSpokenAssistantText = "";
  String? lastUserCommandText;

  Timer? _speechDebounceTimer;
  String _bufferedSpeech = "";

  ChatViewModel({
    required this.schemaRepo,
    required this.audioService,
    required this.ttsService,
  }) {
    ttsService.onStart = () {
      isAssistantSpeaking = true;
      _handleTtsStarted();
      notifyListeners();
    };
    ttsService.onCompletion = () {
      isAssistantSpeaking = false;
      _handleTtsCompleted();
      notifyListeners();
    };
  }

  void _handleTtsStarted() {
    _speechDebounceTimer?.cancel();
    _bufferedSpeech = "";
    currentPartialSpeech = "";
    if (isListening) {
      // Silenciar temporalmente el micrófono de Vosk mientras el altavoz habla
      // para evitar el ciclo de retroalimentación acústica
      audioService.stopListening();
    }
  }

  void _handleTtsCompleted() {
    if (isListening) {
      // Reanudar la escucha de Vosk con un guard delay de 400ms para que la reverberación desaparezca
      Future.delayed(const Duration(milliseconds: 400), () {
        if (isListening && !isAssistantSpeaking) {
          _startVoskListeningInternal();
        }
      });
    }
  }

  void toggleVoiceLiveMode() {
    isVoiceLiveMode = !isVoiceLiveMode;
    notifyListeners();
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    try {
      await ttsService.initialize();
      await audioService.initialize();

      entities = await schemaRepo.fetchAndParseOpenApi();
      stateMachine = DialogStateMachine(entities: entities, baseUrl: schemaRepo.baseUrl);

      statusMessage = "Conectado | ${entities.length} Entidades";
      final welcome =
          "Esquema sincronizado exitosamente.\nEntidades detectadas: ${entities.map((e) => e.entityName).join(', ')}.\nPuedes hablar o emitir un comando.";
      _addAssistantMessage(welcome);
      lastSpokenAssistantText =
          "Esquema sincronizado con éxito. ${entities.length} entidades listas. ¿Qué deseas consultar o registrar?";

      // Síntesis de voz de bienvenida
      ttsService.speak(lastSpokenAssistantText);
    } catch (e) {
      statusMessage = "Desconectado de ${schemaRepo.baseUrl}";
      final err =
          "No se pudo conectar con el servidor en ${schemaRepo.baseUrl}.\nAsegúrate de haber ejecutado:\n'adb reverse tcp:8080 tcp:8080'";
      _addAssistantMessage(err);
      lastSpokenAssistantText = "Sin conexión al backend en el puerto 8080.";
      ttsService.speak(lastSpokenAssistantText);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendUserMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (_isProcessing) return;

    _speechDebounceTimer?.cancel();
    _bufferedSpeech = "";
    currentPartialSpeech = "";

    _isProcessing = true;
    lastUserCommandText = clean;
    messages.add(ChatMessage(text: clean, isUser: true));
    notifyListeners();

    if (stateMachine == null) {
      final msg = "Error: El esquema OpenAPI no está sincronizado.";
      _addAssistantMessage(msg);
      lastSpokenAssistantText = msg;
      _isProcessing = false;
      notifyListeners();
      ttsService.speak(msg);
      return;
    }

    try {
      final response = await stateMachine!.processInput(clean);
      lastSpokenAssistantText = response;
      _addAssistantMessage(response);

      // Síntesis de voz (TTS) para el usuario
      ttsService.speak(response);
    } catch (e) {
      final err = "Error al procesar: $e";
      _addAssistantMessage(err);
      lastSpokenAssistantText = err;
      ttsService.speak(err);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void toggleListening() async {
    if (isListening) {
      _speechDebounceTimer?.cancel();
      final pending = _bufferedSpeech.trim();
      _bufferedSpeech = "";
      currentPartialSpeech = "";
      isListening = false;
      await audioService.stopListening();
      notifyListeners();

      if (pending.isNotEmpty && !_isProcessing && !isAssistantSpeaking) {
        await sendUserMessage(pending);
      }
    } else {
      isListening = true;
      _bufferedSpeech = "";
      currentPartialSpeech = "";
      notifyListeners();

      await _startVoskListeningInternal();
    }
  }

  Future<void> _startVoskListeningInternal() async {
    await audioService.startListening(
      onPartial: (partial) {
        if (!isListening || isAssistantSpeaking) return;
        currentPartialSpeech = _bufferedSpeech.isEmpty ? partial : "$_bufferedSpeech $partial";
        notifyListeners();
      },
      onResult: (resultText) {
        _handleSpeechResult(resultText);
      },
    );
  }

  void _handleSpeechResult(String resultText) {
    if (!isListening || isAssistantSpeaking || _isProcessing) return;
    final clean = resultText.trim();
    if (clean.isEmpty) return;

    // Acumular la frase reconocida
    if (_bufferedSpeech.isEmpty) {
      _bufferedSpeech = clean;
    } else {
      _bufferedSpeech = "$_bufferedSpeech $clean";
    }
    currentPartialSpeech = _bufferedSpeech;
    notifyListeners();

    // End-Of-Utterance debounce timer (900ms)
    // Permite al usuario hacer pausas naturales sin que se corte a la mitad ni envíe 3 mensajes separados
    _speechDebounceTimer?.cancel();
    _speechDebounceTimer = Timer(const Duration(milliseconds: 900), () async {
      final toSend = _bufferedSpeech.trim();
      _bufferedSpeech = "";
      currentPartialSpeech = "";
      if (toSend.isNotEmpty && !_isProcessing && !isAssistantSpeaking) {
        await sendUserMessage(toSend);
      }
    });
  }

  void cancelCurrentOperation() {
    _speechDebounceTimer?.cancel();
    _bufferedSpeech = "";
    currentPartialSpeech = "";
    stateMachine?.reset();
    const cancelMsg = "Operación cancelada.";
    _addAssistantMessage(cancelMsg);
    lastSpokenAssistantText = cancelMsg;
    ttsService.speak(cancelMsg);
    notifyListeners();
  }

  void toggleTts() {
    ttsService.toggleEnabled();
    notifyListeners();
  }

  void _addAssistantMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: false));
    notifyListeners();
  }

  @override
  void dispose() {
    _speechDebounceTimer?.cancel();
    audioService.dispose();
    ttsService.stop();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool isEnabled = true;
  bool isSpeaking = false;

  void Function()? onStart;
  void Function()? onCompletion;

  Future<void> initialize() async {
    try {
      // 1. En dispositivos Android, forzar el motor oficial de Google TTS si está presente
      try {
        final engines = await _flutterTts.getEngines;
        if (engines is List && engines.contains("com.google.android.tts")) {
          await _flutterTts.setEngine("com.google.android.tts");
        }
      } catch (e) {
        debugPrint("[TTS] Advertencia al configurar motor: $e");
      }

      // 2. Probar variantes de idioma español admitidas
      bool langConfigured = false;
      for (final lang in ["es-ES", "es-US", "es-419", "es"]) {
        try {
          final isAvail = await _flutterTts.isLanguageAvailable(lang);
          if (isAvail == 1 || isAvail == true) {
            await _flutterTts.setLanguage(lang);
            langConfigured = true;
            break;
          }
        } catch (_) {}
      }
      if (!langConfigured) {
        await _flutterTts.setLanguage("es");
      }

      await _flutterTts.setSpeechRate(0.50);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      // En Android, QUEUE_FLUSH = 0 garantiza que no haya retrasos ni colas residuales
      await _flutterTts.setQueueMode(0);
      await _flutterTts.awaitSpeakCompletion(true);

      _flutterTts.setStartHandler(() {
        isSpeaking = true;
        onStart?.call();
      });

      _flutterTts.setCompletionHandler(() {
        isSpeaking = false;
        onCompletion?.call();
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("[TTS] Error reportado por el motor: $msg");
        isSpeaking = false;
        onCompletion?.call();
      });
    } catch (e) {
      debugPrint("[TTS] Error durante inicialización: $e");
    }
  }

  Future<void> speak(String text) async {
    if (!isEnabled || text.trim().isEmpty) return;
    final clean = _sanitizeForSpeech(text);
    if (clean.isEmpty) return;

    try {
      isSpeaking = true;
      onStart?.call();
      await _flutterTts.speak(clean);
    } catch (e) {
      debugPrint("[TTS] Excepción al reproducir voz: $e");
    } finally {
      isSpeaking = false;
      onCompletion?.call();
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    isSpeaking = false;
    onCompletion?.call();
  }

  void toggleEnabled() {
    isEnabled = !isEnabled;
    if (!isEnabled) {
      stop();
    }
  }

  String _sanitizeForSpeech(String input) {
    return input
        .replaceAll(RegExp(r'\*\*'), '') // Negritas markdown
        .replaceAll(RegExp(r'\*'), '')   // Cursivas markdown
        .replaceAll(RegExp(r'#+\s*'), '') // Títulos markdown
        .replaceAll(RegExp(r'[`_]'), '')  // Códigos y guiones bajos
        .replaceAll(RegExp(r'https?://\S+'), 'enlace web')
        .replaceAll('\n', '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

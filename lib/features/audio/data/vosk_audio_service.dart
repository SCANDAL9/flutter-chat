import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

class VoskAudioService {
  VoskFlutterPlugin? _vosk;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  StreamSubscription? _resultSub;
  StreamSubscription? _partialSub;

  bool _isInitialized = false;
  bool isListening = false;

  Future<bool> initialize({String? modelAssetPath}) async {
    if (_isInitialized) return true;

    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false;
      }

      _vosk ??= VoskFlutterPlugin.instance();
      final path = modelAssetPath ?? 'assets/models/vosk-model-small-es-0.42.zip';
      final loadedModelPath = await ModelLoader().loadFromAssets(path);
      _model = await _vosk!.createModel(loadedModelPath);
      _recognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );
      _speechService = await _vosk!.initSpeechService(_recognizer!);
      _isInitialized = true;
      return true;
    } catch (_) {
      // Entorno de test / sin modelo
      return false;
    }
  }

  Future<void> startListening({
    required Function(String partial) onPartial,
    required Function(String result) onResult,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    try {
      // Cancelar suscripciones previas para evitar duplicación de eventos
      await _cancelSubscriptions();

      _partialSub = _speechService?.onPartial().listen((partialJson) {
        try {
          final map = jsonDecode(partialJson);
          final text = map['partial']?.toString() ?? '';
          if (text.isNotEmpty) onPartial(text);
        } catch (_) {}
      });

      _resultSub = _speechService?.onResult().listen((resultJson) {
        try {
          final map = jsonDecode(resultJson);
          final text = map['text']?.toString() ?? '';
          if (text.isNotEmpty) onResult(text);
        } catch (_) {}
      });

      await _speechService?.start();
      isListening = true;
    } catch (_) {
      isListening = false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _cancelSubscriptions();
      await _speechService?.stop();
    } catch (_) {}
    isListening = false;
  }

  Future<void> _cancelSubscriptions() async {
    await _partialSub?.cancel();
    _partialSub = null;
    await _resultSub?.cancel();
    _resultSub = null;
  }

  void dispose() {
    _cancelSubscriptions();
    _speechService?.dispose();
    _recognizer?.dispose();
    _model?.dispose();
    _isInitialized = false;
    isListening = false;
  }
}

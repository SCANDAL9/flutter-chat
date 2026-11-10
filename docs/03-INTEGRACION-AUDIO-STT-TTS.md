# Integración de Audio Offline: Reconocimiento (STT) y Síntesis (TTS)

## 1. Justificación Tecnológica

Para operar sin acceso a servicios en la nube (como Google Cloud Speech o OpenAI Whisper API) y manteniéndose dentro de los límites de memoria (~1 GB libre):

1. **Reconocimiento de Voz (STT):** Se selecciona **Vosk Engine** con el modelo acústico optimizado para español `vosk-model-small-es-0.42`. El modelo ocupa aproximadamente 43 MB en almacenamiento y consume entre 35 MB y 50 MB de memoria RAM durante la inferencia.
2. **Síntesis de Voz (TTS):** Se utiliza el motor nativo del sistema operativo Android a través del paquete `flutter_tts`. No requiere modelos adicionales ni consumo de memoria en la capa de la aplicación, pues aprovecha el servicio del sistema preinstalado en el dispositivo.

---

## 2. Configuración del Reconocedor Vosk en Flutter

### Dependencias requeridas en `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  vosk_flutter: ^0.3.2
  record: ^5.1.2
  path_provider: ^2.1.4
  flutter_tts: ^4.1.0
  permission_handler: ^11.3.1
```

### Configuración del Modelo en Android Assets
El modelo acústico debe descomprimirse en el directorio de assets del proyecto Flutter:
```text
assets/
└── models/
    └── vosk-model-small-es-0.42/
        ├── am/
        ├── conf/
        ├── graph/
        └── ivector/
```
Declaración en `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/models/vosk-model-small-es-0.42/
```

### Clase de Servicio de Audio (`VoskAudioService`)
```dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

class VoskAudioService {
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Carga del modelo acústico desde el paquete local
    final modelPath = await ModelLoader().loadFromAssets(
      'assets/models/vosk-model-small-es-0.42.zip',
    );
    _model = await _vosk.createModel(modelPath);
    
    // Tasa de muestreo estándar: 16000 Hz, canal mono
    _recognizer = await _vosk.createRecognizer(
      model: _model!,
      sampleRate: 16000,
    );

    _speechService = await _vosk.initSpeechService(_recognizer!);
    _isInitialized = true;
  }

  Future<void> startListening({
    required Function(String partial) onPartial,
    required Function(String result) onResult,
  }) async {
    if (!_isInitialized) await initialize();

    _speechService?.onPartial().listen(onPartial);
    _speechService?.onResult().listen(onResult);

    await _speechService?.start();
  }

  Future<void> stopListening() async {
    await _speechService?.stop();
  }

  void dispose() {
    _speechService?.dispose();
    _recognizer?.dispose();
    _model?.dispose();
  }
}
```

---

## 3. Configuración del Motor de Síntesis de Voz (TTS)

### Permisos y Configuración en Android (`AndroidManifest.xml`)
Para Android 11+ (API nivel 30 o superior), es obligatorio declarar la intención del servicio TTS:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.INTERNET"/>

    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>
</manifest>
```

### Clase de Servicio TTS (`TtsService`)
```dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool isEnabled = true;

  Future<void> initialize() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5); // Velocidad natural
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> speak(String text) async {
    if (!isEnabled || text.trim().isEmpty) return;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void toggleEnabled() {
    isEnabled = !isEnabled;
    if (!isEnabled) {
      stop();
    }
  }
}
```

---

## 4. Detección de Silencio y Ciclo Manos Libres

Para un funcionamiento manos libres fluido:

1. **VAD (Voice Activity Detection):** El motor Vosk incluye detección integrada de silencio. Al detectar una pausa prolongada (aproximadamente 1.2 segundos tras la última palabra pronunciada), el reconocedor emite el evento `onResult` final.
2. **Ciclo de Turnos:**
   * La aplicación escucha la orden del usuario.
   * Se procesa la intención.
   * Si faltan campos o se reporta el resultado, se desactiva temporalmente el micrófono, el motor TTS reproduce la respuesta en voz alta y, al finalizar la reproducción (`awaitSpeakCompletion(true)`), se reactiva automáticamente la escucha para el siguiente turno.

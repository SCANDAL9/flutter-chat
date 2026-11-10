# Documento 06: Implementación en Flutter: Código Fuente de Componentes Clave

## 1. Módulo de Dominio: Descriptores de Esquema Dinámico

### `lib/features/schema/domain/entity_descriptor.dart`
```dart
class EntityDescriptor {
  final String entityName;
  final String pluralRoute;
  final List<FieldDescriptor> fields;
  final Set<String> requiredFields;

  EntityDescriptor({
    required this.entityName,
    required this.pluralRoute,
    required this.fields,
    required this.requiredFields,
  });

  FieldDescriptor? findField(String fieldName) {
    for (final f in fields) {
      if (f.name.toLowerCase() == fieldName.toLowerCase()) return f;
    }
    return null;
  }
}

class FieldDescriptor {
  final String name;
  final String type; // string, integer, number, boolean
  final String? format; // int32, int64, double, date
  final bool isRequired;
  final List<String>? enumValues;

  FieldDescriptor({
    required this.name,
    required this.type,
    this.format,
    required this.isRequired,
    this.enumValues,
  });
}
```

---

## 2. Ingestor de Esquema OpenAPI 3.0

### `lib/features/schema/data/schema_repository.dart`
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/entity_descriptor.dart';

class SchemaRepository {
  final String baseUrl;

  SchemaRepository({this.baseUrl = 'http://localhost:8080'});

  Future<List<EntityDescriptor>> fetchAndParseOpenApi() async {
    final uri = Uri.parse('$baseUrl/v3/api-docs');
    final response = await http.get(uri).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('Tiempo de espera agotado al conectar con $baseUrl'),
    );

    if (response.statusCode != 200) {
      throw Exception('Error del servidor: HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> spec = jsonDecode(response.body);
    final List<EntityDescriptor> entities = [];
    final schemas = spec['components']?['schemas'] as Map<String, dynamic>? ?? {};

    schemas.forEach((key, value) {
      if (key.endsWith('Request')) {
        final rawName = key.replaceAll('Request', '');
        final props = value['properties'] as Map<String, dynamic>? ?? {};
        final requiredSet = (value['required'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            {};

        final fields = <FieldDescriptor>[];
        props.forEach((pName, pData) {
          fields.add(FieldDescriptor(
            name: pName,
            type: pData['type']?.toString() ?? 'string',
            format: pData['format']?.toString(),
            isRequired: requiredSet.contains(pName),
            enumValues: (pData['enum'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
          ));
        });

        entities.add(EntityDescriptor(
          entityName: rawName,
          pluralRoute: _pluralize(rawName.toLowerCase()),
          fields: fields,
          requiredFields: requiredSet,
        ));
      }
    });

    return entities;
  }

  String _pluralize(String text) {
    if (text.endsWith('s') || text.endsWith('x')) return '${text}es';
    if (text.endsWith('r') || text.endsWith('l') || text.endsWith('n') || text.endsWith('d')) {
      return '${text}es';
    }
    return '${text}s';
  }
}
```

---

## 3. Motor NLU y Máquina de Diálogo Multi-Turno

### `lib/features/nlu/logic/dialog_state_machine.dart`
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../schema/domain/entity_descriptor.dart';

enum IntentType { create, read, update, delete, unknown }

class DialogStateMachine {
  final List<EntityDescriptor> entities;
  final String baseUrl;

  EntityDescriptor? activeEntity;
  IntentType activeIntent = IntentType.unknown;
  final Map<String, dynamic> collectedSlots = {};
  bool isCollecting = false;

  DialogStateMachine({
    required this.entities,
    this.baseUrl = 'http://localhost:8080',
  });

  Future<String> processInput(String rawInput) async {
    final input = rawInput.toLowerCase().trim();

    if (input == 'cancelar' || input == 'salir' || input == 'olvídalo') {
      reset();
      return "Operación cancelada exitosamente.";
    }

    if (isCollecting && activeEntity != null) {
      return await _continueSlotFilling(rawInput);
    }

    final intent = _resolveIntent(input);
    final entity = _resolveEntity(input);

    if (intent == IntentType.unknown || entity == null) {
      return "No reconocí la instrucción. Prueba diciendo 'registrar nuevo cliente' o 'listar productos'.";
    }

    activeIntent = intent;
    activeEntity = entity;
    collectedSlots.clear();

    if (intent == IntentType.read) {
      return await _executeGetAll(entity);
    }

    if (intent == IntentType.create) {
      _extractInitialSlots(rawInput, entity);
      return await _checkRequiredSlots();
    }

    return "Operación aún no soportada para esta entidad.";
  }

  IntentType _resolveIntent(String text) {
    if (text.contains('crear') || text.contains('agregar') || text.contains('nuevo') || text.contains('nueva') || text.contains('registrar')) {
      return IntentType.create;
    }
    if (text.contains('listar') || text.contains('mostrar') || text.contains('ver') || text.contains('consultar')) {
      return IntentType.read;
    }
    return IntentType.unknown;
  }

  EntityDescriptor? _resolveEntity(String text) {
    for (final e in entities) {
      if (text.contains(e.entityName.toLowerCase()) || text.contains(e.pluralRoute)) {
        return e;
      }
    }
    return null;
  }

  void _extractInitialSlots(String text, EntityDescriptor entity) {
    for (final field in entity.fields) {
      final regex = RegExp('${field.name}\\s+([a-zA-Z0-9@._-]+)', caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null) {
        collectedSlots[field.name] = _cast(match.group(1)!, field.type);
      }
    }
  }

  Future<String> _continueSlotFilling(String userInput) async {
    final missing = _getMissingFields();
    if (missing.isEmpty) return await _executeCreate();

    final targetField = missing.first;
    collectedSlots[targetField.name] = _cast(userInput.trim(), targetField.type);

    return await _checkRequiredSlots();
  }

  Future<String> _checkRequiredSlots() async {
    final missing = _getMissingFields();
    if (missing.isNotEmpty) {
      isCollecting = true;
      final names = missing.map((e) => e.name).join(', ');
      return "¿Cuál es el valor para el campo obligatorio: $names?";
    }

    isCollecting = false;
    return await _executeCreate();
  }

  List<FieldDescriptor> _getMissingFields() {
    return activeEntity!.fields
        .where((f) => f.isRequired && !collectedSlots.containsKey(f.name))
        .toList();
  }

  Future<String> _executeCreate() async {
    final uri = Uri.parse('$baseUrl/api/${activeEntity!.pluralRoute}');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(collectedSlots),
      );

      final name = activeEntity!.entityName;
      reset();

      if (res.statusCode == 201 || res.statusCode == 200) {
        return "Registro de $name creado exitosamente en el servidor.";
      }
      return "El servidor rechazó la solicitud (Código ${res.statusCode}).";
    } catch (e) {
      reset();
      return "Error de comunicación con el backend: $e";
    }
  }

  Future<String> _executeGetAll(EntityDescriptor entity) async {
    final uri = Uri.parse('$baseUrl/api/${entity.pluralRoute}');
    try {
      final res = await http.get(uri);
      reset();
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return "Se encontraron ${list.length} registros para ${entity.entityName}.";
      }
      return "Error al listar: Código ${res.statusCode}.";
    } catch (e) {
      reset();
      return "Fallo de conexión al listar: $e";
    }
  }

  dynamic _cast(String value, String type) {
    if (type == 'integer') return int.tryParse(value) ?? 0;
    if (type == 'number') return double.tryParse(value) ?? 0.0;
    if (type == 'boolean') return value.toLowerCase() == 'true' || value.toLowerCase() == 'sí';
    return value;
  }

  void reset() {
    activeEntity = null;
    activeIntent = IntentType.unknown;
    collectedSlots.clear();
    isCollecting = false;
  }
}
```

---

## 4. ViewModel Principal del Chat

### `lib/features/chat/presentation/chat_viewmodel.dart`
```dart
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
  String statusMessage = "Iniciando...";

  ChatViewModel({
    required this.schemaRepo,
    required this.audioService,
    required this.ttsService,
  });

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    try {
      await ttsService.initialize();
      await audioService.initialize();

      entities = await schemaRepo.fetchAndParseOpenApi();
      stateMachine = DialogStateMachine(entities: entities, baseUrl: schemaRepo.baseUrl);

      statusMessage = "Conectado | ${entities.length} Entidades";
      _addAssistantMessage("Esquema sincronizado. Puedes dictar o escribir comandos.");
    } catch (e) {
      statusMessage = "Error de conexión con backend";
      _addAssistantMessage("No se pudo conectar a ${schemaRepo.baseUrl}. Verifica el túnel ADB.");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendUserMessage(String text) async {
    if (text.trim().isEmpty || stateMachine == null) return;

    messages.add(ChatMessage(text: text, isUser: true));
    notifyListeners();

    final response = await stateMachine!.processInput(text);
    _addAssistantMessage(response);

    // Reproducción TTS si está activo
    await ttsService.speak(response);
  }

  void toggleListening() async {
    if (isListening) {
      await audioService.stopListening();
      isListening = false;
    } else {
      isListening = true;
      notifyListeners();

      await audioService.startListening(
        onPartial: (p) {},
        onResult: (resultText) async {
          if (resultText.trim().isNotEmpty) {
            await sendUserMessage(resultText);
          }
        },
      );
    }
    notifyListeners();
  }

  void _addAssistantMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: false));
    notifyListeners();
  }
}
```

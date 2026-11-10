# Estructura del Proyecto Flutter y Componentes de Código

## 1. Organización del Código (Clean Architecture por Features)

El proyecto adopta una estructura modular orientada a características (*Feature-First*), separando la lógica de dominio de las fuentes de datos y la interfaz de usuario:

```text
lib/
├── core/
│   ├── network/
│   │   ├── api_client.dart            # Cliente HTTP base (Dio / http)
│   │   └── network_exceptions.dart    # Mapeo de errores de red y HTTP
│   ├── theme/
│   │   └── app_theme.dart             # Paleta de colores y estilos de chat
│   └── utils/
│       └── string_similarity.dart     # Algoritmo Levenshtein para matching fonético
├── features/
│   ├── audio/
│   │   ├── data/
│   │   │   ├── tts_service.dart       # Implementación flutter_tts
│   │   │   └── vosk_audio_service.dart# Implementación vosk_flutter
│   │   └── presentation/
│   │       └── audio_controller.dart  # Gestión del estado del micrófono y VAD
│   ├── schema/
│   │   ├── domain/
│   │   │   ├── entity_descriptor.dart # Modelo de entidades, campos y tipos
│   │   │   └── openapi_contract.dart  # Representación del contrato OpenAPI
│   │   └── data/
│   │       └── schema_repository.dart # Descarga y parseo de /v3/api-docs
│   ├── nlu/
│   │   ├── domain/
│   │   │   ├── intent.dart            # Enumeración de intenciones (CREATE, READ, etc.)
│   │   │   └── conversation_state.dart# Estado de la máquina de slot-filling
│   │   └── logic/
│   │       ├── intent_classifier.dart # Clasificación de intención y entidad
│   │       ├── slot_extractor.dart    # Extracción de valores de campos
│   │       └── dialog_state_machine.dart# Orquestador multi-turn
│   └── chat/
│       ├── domain/
│       │   └── chat_message.dart      # Mensaje de usuario o asistente
│       └── presentation/
│           ├── chat_screen.dart       # Pantalla principal del chat
│           ├── chat_viewmodel.dart    # ViewModel / Controlador del chat
│           └── widgets/
│               ├── chat_bubble.dart   # Burbuja de texto y tarjetas dinámicas
│               ├── mic_indicator.dart # Animación de onda de escucha
│               └── tts_toggle_btn.dart# Botón de encendido/apagado de voz
└── main.dart                          # Inicialización de la aplicación
```

---

## 2. Ingestor del Contrato OpenAPI (`SchemaRepository`)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/entity_descriptor.dart';

class SchemaRepository {
  final String baseUrl;

  SchemaRepository({this.baseUrl = 'http://localhost:8080'});

  Future<List<EntityDescriptor>> fetchAndParseOpenApiSpec() async {
    final response = await http.get(Uri.parse('$baseUrl/v3/api-docs'));

    if (response.statusCode != 200) {
      throw Exception('Fallo al obtener especificación OpenAPI: ${response.statusCode}');
    }

    final Map<String, dynamic> spec = jsonDecode(response.body);
    final List<EntityDescriptor> entities = [];

    final schemas = spec['components']?['schemas'] as Map<String, dynamic>? ?? {};

    // Cada entidad en UmlStudio genera un par {Entidad}Request y {Entidad}Response
    schemas.forEach((schemaName, schemaData) {
      if (schemaName.endsWith('Request')) {
        final entityName = schemaName.replaceAll('Request', '');
        final properties = schemaData['properties'] as Map<String, dynamic>? ?? {};
        final requiredList = (schemaData['required'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {};

        final List<FieldDescriptor> fields = [];
        properties.forEach((propName, propData) {
          fields.add(FieldDescriptor(
            name: propName,
            type: propData['type']?.toString() ?? 'string',
            isRequired: requiredList.contains(propName),
          ));
        });

        // La ruta REST sigue la convención de UmlStudio: plural de la entidad
        final pluralRoute = _pluralize(entityName.toLowerCase());

        entities.add(EntityDescriptor(
          entityName: entityName,
          pluralRoute: pluralRoute,
          fields: fields,
          requiredFields: requiredList,
        ));
      }
    });

    return entities;
  }

  String _pluralize(String singular) {
    if (singular.endsWith('s') || singular.endsWith('x')) return '${singular}es';
    if (singular.endsWith('r') || singular.endsWith('l') || singular.endsWith('n') || singular.endsWith('d')) {
      return '${singular}es';
    }
    return '${singular}s';
  }
}
```

---

## 3. Orquestador de la Máquina de Estados (`DialogStateMachine`)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../schema/domain/entity_descriptor.dart';
import '../domain/intent.dart';

class DialogStateMachine {
  final List<EntityDescriptor> availableEntities;
  final String baseUrl;

  EntityDescriptor? activeEntity;
  UserIntent? activeIntent;
  Map<String, dynamic> collectedSlots = {};
  bool isCollecting = false;

  DialogStateMachine({
    required this.availableEntities,
    this.baseUrl = 'http://localhost:8080',
  });

  Future<String> processUserInput(String input) async {
    final lower = input.toLowerCase().trim();

    // 1. Manejo de comando de cancelación
    if (lower == 'cancelar' || lower == 'olvídalo' || lower == 'salir') {
      reset();
      return "Operación cancelada.";
    }

    // 2. Si ya estamos en estado de recolección de campos (multi-turn)
    if (isCollecting && activeEntity != null) {
      return await _continueCollectingSlots(input);
    }

    // 3. Identificación de nueva intención
    final intent = _resolveIntent(lower);
    final entity = _resolveEntity(lower);

    if (intent == UserIntent.UNKNOWN || entity == null) {
      return "No logré identificar la acción o la entidad solicitada. Prueba con 'registrar cliente' o 'listar productos'.";
    }

    activeIntent = intent;
    activeEntity = entity;
    collectedSlots.clear();

    if (intent == UserIntent.READ) {
      return await _executeGetAll(entity);
    }

    if (intent == UserIntent.CREATE) {
      _extractInitialSlots(input, entity);
      return await _evaluateSlotCompletion();
    }

    return "La acción solicitada aún no está implementada.";
  }

  UserIntent _resolveIntent(String text) {
    if (text.contains('crear') || text.contains('agregar') || text.contains('nuevo') || text.contains('registrar')) {
      return UserIntent.CREATE;
    }
    if (text.contains('listar') || text.contains('mostrar') || text.contains('ver') || text.contains('consultar')) {
      return UserIntent.READ;
    }
    if (text.contains('actualizar') || text.contains('modificar')) {
      return UserIntent.UPDATE;
    }
    if (text.contains('eliminar') || text.contains('borrar')) {
      return UserIntent.DELETE;
    }
    return UserIntent.UNKNOWN;
  }

  EntityDescriptor? _resolveEntity(String text) {
    for (final entity in availableEntities) {
      if (text.contains(entity.entityName.toLowerCase()) || text.contains(entity.pluralRoute)) {
        return entity;
      }
    }
    return null;
  }

  void _extractInitialSlots(String text, EntityDescriptor entity) {
    // Extracción básica basada en nombres de campos definidos en el contrato
    for (final field in entity.fields) {
      final pattern = RegExp('${field.name}\\s+([a-zA-Z0-9@._-]+)', caseSensitive: false);
      final match = pattern.firstMatch(text);
      if (match != null) {
        collectedSlots[field.name] = _castValue(match.group(1)!, field.type);
      }
    }
  }

  Future<String> _continueCollectingSlots(String input) async {
    final missingFields = _getMissingRequiredFields();
    if (missingFields.isEmpty) {
      return await _executeCreate();
    }

    // Se asigna la respuesta al primer campo pendiente
    final targetField = missingFields.first;
    collectedSlots[targetField.name] = _castValue(input.trim(), targetField.type);

    return await _evaluateSlotCompletion();
  }

  Future<String> _evaluateSlotCompletion() async {
    final missing = _getMissingRequiredFields();
    if (missing.isNotEmpty) {
      isCollecting = true;
      final names = missing.map((e) => e.name).join(', ');
      return "¿Cuál es el valor para el campo obligatorio: $names?";
    }

    isCollecting = false;
    return await _executeCreate();
  }

  List<FieldDescriptor> _getMissingRequiredFields() {
    return activeEntity!.fields.where((f) {
      return f.isRequired && !collectedSlots.containsKey(f.name);
    }).toList();
  }

  Future<String> _executeCreate() async {
    final url = '$baseUrl/api/${activeEntity!.pluralRoute}';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(collectedSlots),
    );

    final entityName = activeEntity!.entityName;
    reset();

    if (response.statusCode == 201 || response.statusCode == 200) {
      return "Registro de $entityName creado exitosamente en el servidor.";
    } else {
      return "Error al crear $entityName: Código ${response.statusCode}.";
    }
  }

  Future<String> _executeGetAll(EntityDescriptor entity) async {
    final url = '$baseUrl/api/${entity.pluralRoute}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      if (list.isEmpty) {
        return "No hay registros cargados para ${entity.entityName}.";
      }
      return "Se encontraron ${list.length} registros para ${entity.entityName}.";
    } else {
      return "Error al consultar ${entity.entityName}: Código ${response.statusCode}.";
    }
  }

  dynamic _castValue(String raw, String type) {
    if (type == 'integer') return int.tryParse(raw) ?? 0;
    if (type == 'number') return double.tryParse(raw) ?? 0.0;
    if (type == 'boolean') return raw.toLowerCase() == 'true' || raw.toLowerCase() == 'sí';
    return raw;
  }

  void reset() {
    activeEntity = null;
    activeIntent = null;
    collectedSlots.clear();
    isCollecting = false;
  }
}
```

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../schema/domain/entity_descriptor.dart';

enum IntentType { create, read, update, delete, unknown }

class DialogStateMachine {
  final List<EntityDescriptor> entities;
  final String baseUrl;

  EntityDescriptor? activeEntity;
  EntityDescriptor? lastExecutedEntity;
  IntentType activeIntent = IntentType.unknown;
  IntentType lastExecutedIntent = IntentType.unknown;
  final Map<String, dynamic> collectedSlots = {};
  Map<String, dynamic> lastExecutedPayload = {};
  dynamic targetId;
  List<Map<String, dynamic>> lastFetchedList = [];
  bool isCollecting = false;

  DialogStateMachine({
    required this.entities,
    this.baseUrl = 'http://localhost:8080',
  });

  /// Pre-normaliza texto acústico para subsanar errores fonéticos de Vosk
  String normalizeSpeech(String raw) {
    var text = raw.toLowerCase().trim();

    // Reemplazos de variantes fonéticas y transcripciones de Vosk
    text = text.replaceAll(RegExp(r'\b(le|el|de|la)\s+estar\b'), 'listar');
    text = text.replaceAll(RegExp(r'\blestar\b'), 'listar');
    text = text.replaceAll(RegExp(r'\b(lista|listame|listado|listeme)\b'), 'listar');
    text = text.replaceAll(RegExp(r'\b(muestra|muestrame|mostrame|mostra)\b'), 'mostrar');
    text = text.replaceAll(RegExp(r'\b(consulta|consultame|busca|buscame)\b'), 'consultar');
    text = text.replaceAll(RegExp(r'\b(crea|creame)\b'), 'crear');
    text = text.replaceAll(RegExp(r'\b(agrega|agregame)\b'), 'agregar');
    text = text.replaceAll(RegExp(r'\b(registra|registrame)\b'), 'registrar');
    text = text.replaceAll(RegExp(r'\b(elimina|eliminame|borra|borrame)\b'), 'eliminar');
    text = text.replaceAll(RegExp(r'\b(modifica|modificame|actualiza|actualizame)\b'), 'actualizar');

    return text;
  }

  Future<String> processInput(String rawInput) async {
    final input = normalizeSpeech(rawInput);

    // 1. Manejo de comando de cancelación
    if (input == 'cancelar' ||
        input == 'salir' ||
        input == 'olvídalo' ||
        input == 'olvidalo' ||
        input == 'cancel') {
      reset();
      lastFetchedList.clear();
      return "Operación cancelada exitosamente.";
    }

    // 2. Si nos encontramos en modo de recolección de ranuras (multi-turno)
    if (isCollecting && activeEntity != null) {
      if (activeIntent == IntentType.delete) {
        final id = resolveTargetId(rawInput, input);
        if (id != null) {
          final ent = activeEntity!;
          return await _executeDelete(ent, id);
        }
        return "¿Cuál es el número o ID del registro de ${activeEntity!.entityName} a eliminar?";
      }

      if (activeIntent == IntentType.read && targetId == null) {
        final id = resolveTargetId(rawInput, input);
        if (id != null) {
          final ent = activeEntity!;
          return await _executeGetById(ent, id);
        }
        return "¿Cuál es el ID del registro de ${activeEntity!.entityName} a consultar?";
      }

      if (activeIntent == IntentType.update) {
        if (targetId == null) {
          final id = resolveTargetId(rawInput, input);
          if (id != null) {
            targetId = id;
            return "¿Qué campos deseas actualizar en ${activeEntity!.entityName} con ID $id?";
          }
          return "¿Cuál es el ID del registro de ${activeEntity!.entityName} a actualizar?";
        }
        _extractSlotsFromText(rawInput, activeEntity!);
        if (collectedSlots.isNotEmpty) {
          final ent = activeEntity!;
          final id = targetId!;
          return await _executeUpdate(ent, id);
        }
        return "Por favor indica los valores a modificar, por ejemplo: 'nombre Pedro edad 30'.";
      }

      return await _continueSlotFilling(rawInput);
    }

    // 3. Resolución de nueva intención
    final intent = _resolveIntent(input);
    final entity = _resolveEntity(input) ?? (isCollecting ? activeEntity : lastExecutedEntity);

    if (intent == IntentType.unknown || entity == null) {
      final sampleName = entities.isNotEmpty ? entities.first.entityName.toLowerCase() : 'registro';
      final samplePlural = entities.isNotEmpty ? entities.first.pluralRoute.toLowerCase() : 'registros';
      return "No reconocí la instrucción. Prueba diciendo 'registrar nuevo $sampleName', 'listar $samplePlural' o 'eliminar $sampleName con id 1'.";
    }

    activeIntent = intent;
    activeEntity = entity;
    collectedSlots.clear();
    targetId = resolveTargetId(rawInput, input);

    // READ (GET ALL o GET BY ID)
    if (intent == IntentType.read) {
      if (targetId != null) {
        return await _executeGetById(entity, targetId!);
      }
      return await _executeGetAll(entity);
    }

    // DELETE (DELETE BY ID)
    if (intent == IntentType.delete) {
      if (targetId != null) {
        return await _executeDelete(entity, targetId!);
      }
      isCollecting = true;
      return "¿Cuál es el ID del registro de ${entity.entityName} que deseas eliminar?";
    }

    // UPDATE (PUT BY ID)
    if (intent == IntentType.update) {
      _extractSlotsFromText(rawInput, entity);
      if (targetId != null && collectedSlots.isNotEmpty) {
        return await _executeUpdate(entity, targetId!);
      }
      isCollecting = true;
      if (targetId == null) {
        return "¿Cuál es el ID del registro de ${entity.entityName} que deseas actualizar?";
      }
      return "¿Qué valores deseas actualizar en ${entity.entityName} $targetId? (ejemplo: 'nombre NuevoNombre')";
    }

    // CREATE (POST)
    if (intent == IntentType.create) {
      _extractSlotsFromText(rawInput, entity);
      return await _checkRequiredSlots();
    }

    return "Operación no soportada en esta versión.";
  }

  static const Map<String, int> _spanishWordToNumber = {
    'cero': 0,
    'un': 1,
    'uno': 1,
    'una': 1,
    'primero': 1,
    'primera': 1,
    'dos': 2,
    'segundo': 2,
    'segunda': 2,
    'tres': 3,
    'tercero': 3,
    'tercera': 3,
    'cuatro': 4,
    'cuarto': 4,
    'cinco': 5,
    'quinto': 5,
    'seis': 6,
    'sexto': 6,
    'siete': 7,
    'séptimo': 7,
    'septimo': 7,
    'ocho': 8,
    'octavo': 8,
    'nueve': 9,
    'noveno': 9,
    'diez': 10,
    'décimo': 10,
    'decimo': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciséis': 16,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintiun': 21,
    'veintiún': 21,
    'veintidós': 22,
    'veintidos': 22,
    'veintitrés': 23,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiséis': 26,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
    'cien': 100,
    'ciento': 100,
  };

  static const Map<String, int> _ordinals = {
    'primero': 0,
    'primer': 0,
    'primera': 0,
    'segundo': 1,
    'segunda': 1,
    'tercero': 2,
    'tercer': 2,
    'tercera': 2,
    'cuarto': 3,
    'cuarta': 3,
    'quinto': 4,
    'quinta': 4,
    'sexto': 5,
    'sexta': 5,
    'séptimo': 6,
    'septimo': 6,
    'séptima': 6,
    'septima': 6,
    'octavo': 7,
    'octava': 7,
    'noveno': 8,
    'novena': 8,
    'décimo': 9,
    'decimo': 9,
    'décima': 9,
    'decima': 9,
  };

  Set<String> get _entityKeywords {
    final set = <String>{};
    for (final e in entities) {
      final name = e.entityName.toLowerCase().trim();
      final route = e.pluralRoute.toLowerCase().trim();
      if (name.isNotEmpty) set.add(name);
      if (route.isNotEmpty) set.add(route);
      set.add('${name}s');
      set.add('${name}es');
      if (name.endsWith('s')) set.add(name.substring(0, name.length - 1));
      if (name.endsWith('es')) set.add(name.substring(0, name.length - 2));
    }
    return set;
  }

  dynamic resolveTargetId(String rawInput, String normalizedInput) {
    // 1. Detección directa de UUID estándar (8-4-4-4-12 hex)
    final uuidRegex = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );
    final uuidMatch = uuidRegex.firstMatch(rawInput);
    if (uuidMatch != null) {
      return uuidMatch.group(0);
    }

    final lower = normalizedInput.toLowerCase();

    // 2. Navegación ordinal si disponemos de registros previos en memoria
    if (lastFetchedList.isNotEmpty) {
      if (lower.contains('último') ||
          lower.contains('ultimo') ||
          lower.contains('última') ||
          lower.contains('ultima')) {
        return lastFetchedList.last['id'];
      }

      for (final entry in _ordinals.entries) {
        final pattern = RegExp('\\b${entry.key}\\b', caseSensitive: false);
        if (pattern.hasMatch(lower)) {
          final idx = entry.value;
          if (idx >= 0 && idx < lastFetchedList.length) {
            return lastFetchedList[idx]['id'];
          }
        }
      }
    }

    // 3. Resolución por clave natural en lastFetchedList (nombre, email, title, code)
    if (lastFetchedList.isNotEmpty) {
      final inputTokens = lower.split(RegExp(r'\s+')).where((t) => t.length >= 3).toSet();
      final entityKw = _entityKeywords;
      for (final item in lastFetchedList) {
        for (final key in ['nombre', 'name', 'title', 'email', 'code', 'codigo']) {
          final val = item[key]?.toString().toLowerCase().trim();
          if (val == null || val.length < 3) continue;
          if (lower.contains(val)) {
            return item['id'];
          }
          // Coincidencia por tokens dentro del nombre (ej: "Juan" coincide con "Juan Perez")
          final valTokens = val.split(RegExp(r'\s+')).where((t) => t.length >= 3);
          for (final vt in valTokens) {
            if (!entityKw.contains(vt) &&
                vt != 'nuevo' &&
                vt != 'nueva' &&
                inputTokens.contains(vt)) {
              return item['id'];
            }
          }
        }
      }
    }

    // 4. Extracción de ID numérico tradicional
    final numId = _extractId(rawInput) ?? _parseStandaloneId(normalizedInput.trim());
    if (numId != null) {
      if (lastFetchedList.isNotEmpty) {
        final hasDirectMatch = lastFetchedList.any(
          (item) => item['id'] == numId || item['id'].toString() == numId.toString(),
        );
        if (hasDirectMatch) {
          return numId;
        }
        // Si los registros usan UUID y el usuario dijo una posición 1-indexada (ej: "el 2")
        if (numId >= 1 && numId <= lastFetchedList.length) {
          return lastFetchedList[numId - 1]['id'];
        }
      }
      return numId;
    }

    return null;
  }

  int? _parseSpanishNumberToken(String token) {
    final t = token.trim().toLowerCase();
    if (RegExp(r'^\d+$').hasMatch(t)) {
      return int.tryParse(t);
    }
    // Caso compuesto: ej. "treinta y dos"
    final compoundParts = t.split(RegExp(r'\s+y\s+'));
    if (compoundParts.length == 2) {
      final tens = _spanishWordToNumber[compoundParts[0]];
      final units = _spanishWordToNumber[compoundParts[1]];
      if (tens != null && units != null) {
        return tens + units;
      }
    }
    return _spanishWordToNumber[t];
  }

  int? _parseStandaloneId(String text) {
    var clean = text.toLowerCase().trim();
    // Limpiar prefijos comunes como "el", "la", "el número", "número", "id", "registro", "#"
    clean = clean.replaceAll(RegExp(r'^(?:el|la|el\s+número|el\s+numero|número|numero|id|código|codigo|registro|#)\s*[:=]?\s*'), '').trim();
    // Limpiar sufijos como "por favor", "gracias"
    clean = clean.replaceAll(RegExp(r'\s+(?:por\s+favor|gracias)$'), '').trim();
    return _parseSpanishNumberToken(clean);
  }

  int? _extractId(String text) {
    final lower = text.toLowerCase().trim();

    // 1. Caso directo de ID aislado (ej: "3", "tres", "el tres", "el 3", "id tres")
    final standalone = _parseStandaloneId(lower);
    if (standalone != null) return standalone;

    // 2. Busca patrones explícitos como: "con id 3", "id tres", "código 3", "número cuatro", "#3"
    final idRegex = RegExp(
      r'(?:con\s+id|id|código|codigo|número|numero|registro|#)\s*[:=]?\s*([a-záéíóúñ0-9]+(?:\s+y\s+[a-záéíóúñ]+)?)',
      caseSensitive: false,
    );
    final match = idRegex.firstMatch(lower);
    if (match != null) {
      final token = match.group(1)!.trim();
      final parsed = _parseSpanishNumberToken(token);
      if (parsed != null) return parsed;
    }

    // 3. Patrones directos entidad + número dinámico: "{entidad} 3", "{entidad} tres"
    final kwList = _entityKeywords.toList();
    if (kwList.isNotEmpty) {
      kwList.sort((a, b) => b.length.compareTo(a.length));
      final entityAlternation = kwList.map(RegExp.escape).join('|');
      final entityIdPattern = RegExp(
        '\\b(?:$entityAlternation)\\s+([a-záéíóúñ0-9]+(?:\\s+y\\s+[a-záéíóúñ]+)?)\\b',
        caseSensitive: false,
      );
      final entityMatch = entityIdPattern.firstMatch(lower);
      if (entityMatch != null) {
        final token = entityMatch.group(1)!.trim();
        if (token != 'nuevo' && token != 'nueva') {
          final parsed = _parseSpanishNumberToken(token);
          if (parsed != null) return parsed;
        }
      }
    }

    // 4. Token numérico con dígitos explícitos (\d+)
    final tokens = lower.split(RegExp(r'\s+'));
    for (final t in tokens) {
      if (RegExp(r'^\d+$').hasMatch(t)) {
        return int.tryParse(t);
      }
    }

    // 5. Palabras numéricas explícitas presentes en la oración (excluyendo artículos 'un' / 'una')
    for (final t in tokens) {
      if (t != 'un' && t != 'una' && _spanishWordToNumber.containsKey(t)) {
        return _spanishWordToNumber[t];
      }
    }

    return null;
  }

  IntentType _resolveIntent(String text) {
    if (text.contains('crear') ||
        text.contains('agregar') ||
        text.contains('nuevo') ||
        text.contains('nueva') ||
        text.contains('registrar') ||
        text.contains('insertar') ||
        text.contains('create') ||
        text.contains('new') ||
        text.contains('add')) {
      return IntentType.create;
    }
    if (text.contains('modificar') ||
        text.contains('actualizar') ||
        text.contains('cambiar') ||
        text.contains('editar') ||
        text.contains('update')) {
      return IntentType.update;
    }
    if (text.contains('eliminar') ||
        text.contains('borrar') ||
        text.contains('quitar') ||
        text.contains('remover') ||
        text.contains('delete') ||
        text.contains('remove')) {
      return IntentType.delete;
    }
    if (text.contains('listar') ||
        text.contains('mostrar') ||
        text.contains('ver') ||
        text.contains('consultar') ||
        text.contains('buscar') ||
        text.contains('list') ||
        text.contains('get') ||
        text.contains('show')) {
      return IntentType.read;
    }

    // Fuzzy matching de respaldo para palabras clave
    final words = text.split(RegExp(r'\s+'));
    for (final w in words) {
      if (w.length < 4) continue;
      if (_calculateSimilarity(w, 'listar') >= 0.70 || _calculateSimilarity(w, 'mostrar') >= 0.70) {
        return IntentType.read;
      }
      if (_calculateSimilarity(w, 'crear') >= 0.70 || _calculateSimilarity(w, 'registrar') >= 0.70) {
        return IntentType.create;
      }
      if (_calculateSimilarity(w, 'eliminar') >= 0.70 || _calculateSimilarity(w, 'borrar') >= 0.70) {
        return IntentType.delete;
      }
      if (_calculateSimilarity(w, 'actualizar') >= 0.70 || _calculateSimilarity(w, 'modificar') >= 0.70) {
        return IntentType.update;
      }
    }

    return IntentType.unknown;
  }

  EntityDescriptor? _resolveEntity(String text) {
    // 1. Coincidencia exacta de substring
    for (final e in entities) {
      final name = e.entityName.toLowerCase();
      final route = e.pluralRoute.toLowerCase();
      if (text.contains(name) || text.contains(route)) {
        return e;
      }
      // Chequear variaciones de plural y singular
      if (text.contains('${name}s') || text.contains('${name}es')) {
        return e;
      }
      if (name.endsWith('s') && text.contains(name.substring(0, name.length - 1))) {
        return e;
      }
    }

    // 2. Coincidencia difusa (Fuzzy Levenshtein) por tokens
    final words = text.split(RegExp(r'\s+'));
    EntityDescriptor? bestMatch;
    double highestScore = 0.0;

    for (final word in words) {
      if (word.length < 3) continue;
      for (final e in entities) {
        final scoreName = _calculateSimilarity(word, e.entityName.toLowerCase());
        final scoreRoute = _calculateSimilarity(word, e.pluralRoute.toLowerCase());
        final maxScore = max(scoreName, scoreRoute);

        if (maxScore > highestScore && maxScore >= 0.65) {
          highestScore = maxScore;
          bestMatch = e;
        }
      }
    }

    return bestMatch;
  }

  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final len1 = s1.length;
    final len2 = s2.length;
    List<int> current = List<int>.generate(len2 + 1, (i) => i);
    List<int> previous = List<int>.filled(len2 + 1, 0);

    for (int i = 0; i < len1; i++) {
      previous = List<int>.from(current);
      current[0] = i + 1;

      for (int j = 0; j < len2; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    final distance = current[len2];
    final maxLen = max(len1, len2);
    return 1.0 - (distance / maxLen);
  }

  void _extractSlotsFromText(String text, EntityDescriptor entity) {
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
    lastExecutedEntity = activeEntity;
    lastExecutedIntent = IntentType.create;
    final entityName = activeEntity?.entityName ?? 'Registro';
    final payload = Map<String, dynamic>.from(collectedSlots);
    lastExecutedPayload = payload;
    final uri = Uri.parse('$baseUrl/api/${activeEntity!.pluralRoute}');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      reset();

      if (res.statusCode == 201 || res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final id = decoded is Map ? decoded['id'] : null;
        final idStr = id != null ? " con ID $id" : "";
        return "Registro de $entityName$idStr creado exitosamente en el servidor.";
      }
      return "El servidor rechazó la solicitud (Código ${res.statusCode}).";
    } catch (e) {
      reset();
      return "Error de red al registrar $entityName: $e";
    }
  }

  Future<String> _executeGetAll(EntityDescriptor entity) async {
    lastExecutedEntity = entity;
    lastExecutedIntent = IntentType.read;
    final uri = Uri.parse('$baseUrl/api/${entity.pluralRoute}');
    try {
      final res = await http.get(uri);
      reset();
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isEmpty) {
          lastFetchedList = [];
          return "No hay registros disponibles para ${entity.entityName}.";
        }

        lastFetchedList = List<Map<String, dynamic>>.from(
          list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );

        final summaries = list.map((item) {
          if (item is Map) {
            final name = item['nombre'] ?? item['name'] ?? item['title'] ?? item['code'] ?? 'ID ${item['id']}';
            final price = item['precio'] ?? item['price'] ?? item['total'] ?? item['monto'];
            final extra = price != null ? ' (\$$price)' : '';
            return "$name$extra";
          }
          return item.toString();
        }).where((s) => s.toString().trim().isNotEmpty).toList();

        if (list.length <= 5) {
          final itemsText = summaries.isNotEmpty ? ": ${summaries.join(', ')}." : ".";
          return "Se encontraron ${list.length} registros para ${entity.entityName}$itemsText";
        } else {
          final top5 = summaries.take(5).join(', ');
          final remaining = list.length - 5;
          return "Se encontraron ${list.length} registros para ${entity.entityName}. Los primeros 5 son: $top5; y $remaining registros más. Podés verlos todos en el Explorador de Base de Datos o consultar uno por su nombre o posición.";
        }
      }
      return "Error del servidor: HTTP ${res.statusCode}.";
    } catch (e) {
      reset();
      return "Fallo de conexión al consultar ${entity.entityName}: $e";
    }
  }

  Future<String> _executeGetById(EntityDescriptor entity, dynamic id) async {
    lastExecutedEntity = entity;
    lastExecutedIntent = IntentType.read;
    final uri = Uri.parse('$baseUrl/api/${entity.pluralRoute}/$id');
    try {
      final res = await http.get(uri);
      reset();
      if (res.statusCode == 200) {
        final item = jsonDecode(res.body) as Map<String, dynamic>;
        final details = item.entries
            .map((e) => "${e.key}: ${e.value}")
            .join(', ');
        return "Detalle de ${entity.entityName} (ID $id): $details";
      }
      if (res.statusCode == 404) {
        return "No se encontró ningún registro de ${entity.entityName} con ID $id.";
      }
      return "Error del servidor: HTTP ${res.statusCode}.";
    } catch (e) {
      reset();
      return "Fallo de conexión al consultar ${entity.entityName} $id: $e";
    }
  }

  Future<String> _executeUpdate(EntityDescriptor entity, dynamic id) async {
    lastExecutedEntity = entity;
    lastExecutedIntent = IntentType.update;
    final uri = Uri.parse('$baseUrl/api/${entity.pluralRoute}/$id');
    try {
      final payload = Map<String, dynamic>.from(collectedSlots);
      lastExecutedPayload = payload;
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      reset();
      if (res.statusCode == 200) {
        return "Registro de ${entity.entityName} con ID $id actualizado exitosamente.";
      }
      if (res.statusCode == 404) {
        return "No se encontró ningún registro de ${entity.entityName} con ID $id para actualizar.";
      }
      return "El servidor rechazó la actualización (Código ${res.statusCode}).";
    } catch (e) {
      reset();
      return "Error de red al actualizar ${entity.entityName} $id: $e";
    }
  }

  Future<String> _executeDelete(EntityDescriptor entity, dynamic id) async {
    lastExecutedEntity = entity;
    lastExecutedIntent = IntentType.delete;
    final uri = Uri.parse('$baseUrl/api/${entity.pluralRoute}/$id');
    try {
      final res = await http.delete(uri);
      reset();
      if (res.statusCode == 204 || res.statusCode == 200) {
        return "Registro de ${entity.entityName} con ID $id eliminado exitosamente.";
      }
      if (res.statusCode == 404) {
        return "No se encontró ningún registro de ${entity.entityName} con ID $id para eliminar.";
      }
      if (res.statusCode == 409) {
        return "No se puede eliminar ${entity.entityName} $id porque posee relaciones activas en el modelo.";
      }
      return "El servidor rechazó la eliminación (Código ${res.statusCode}).";
    } catch (e) {
      reset();
      return "Error de red al eliminar ${entity.entityName} $id: $e";
    }
  }

  dynamic _cast(String value, String type) {
    if (type == 'integer') return int.tryParse(value) ?? _parseSpanishNumberToken(value) ?? 0;
    if (type == 'number') return double.tryParse(value) ?? _parseSpanishNumberToken(value)?.toDouble() ?? 0.0;
    if (type == 'boolean') {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == 'sí' || lower == 'si';
    }
    return value;
  }

  void reset() {
    activeEntity = null;
    activeIntent = IntentType.unknown;
    collectedSlots.clear();
    targetId = null;
    isCollecting = false;
  }
}

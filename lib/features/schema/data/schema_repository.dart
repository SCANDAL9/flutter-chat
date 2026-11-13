import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/entity_descriptor.dart';

class SchemaRepository {
  String baseUrl;

  SchemaRepository({this.baseUrl = 'http://localhost:8080'});

  Future<List<EntityDescriptor>> fetchAndParseOpenApi() async {
    final uri = Uri.parse('$baseUrl/v3/api-docs');
    final response = await http.get(uri).timeout(
      const Duration(seconds: 4),
      onTimeout: () => throw Exception('Timeout al conectar con $baseUrl'),
    );

    if (response.statusCode != 200) {
      throw Exception('Respuesta HTTP no válida: ${response.statusCode}');
    }

    final Map<String, dynamic> spec = jsonDecode(utf8.decode(response.bodyBytes));
    return parseOpenApiMap(spec);
  }

  static List<EntityDescriptor> parseOpenApiMap(Map<String, dynamic> spec) {
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
          pluralRoute: toKebabPlural(rawName),
          fields: fields,
          requiredFields: requiredSet,
        ));
      }
    });

    return entities;
  }

  static String toKebabPlural(String pascalCase) {
    // 1. Convert PascalCase to kebab-case
    final kebab = pascalCase.replaceAllMapped(
      RegExp(r'(?<=[a-z])[A-Z]'),
      (Match m) => '-${m.group(0)}',
    ).toLowerCase();

    // 2. Pluralize following UmlStudio conventions
    if (kebab.endsWith('s') || kebab.endsWith('x')) return '${kebab}es';
    if (kebab.endsWith('r') || kebab.endsWith('l') || kebab.endsWith('n') || kebab.endsWith('d')) {
      return '${kebab}es';
    }
    return '${kebab}s';
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:umlstudio_mobile/features/schema/data/schema_repository.dart';

void main() {
  group('CU-07: SchemaRepository & OpenAPI Ingestion Suite', () {
    test('Pluralization covers complex English and Spanish noun morphology', () {
      // Reglas generales
      expect(SchemaRepository.toKebabPlural('Usuario'), equals('usuarios'));
      expect(SchemaRepository.toKebabPlural('Cliente'), equals('clientes'));
      expect(SchemaRepository.toKebabPlural('Venta'), equals('ventas'));

      // Nombres compuestos en PascalCase -> kebab-case plural
      expect(SchemaRepository.toKebabPlural('DetalleVenta'), equals('detalle-ventas'));
      expect(SchemaRepository.toKebabPlural('ProductoStock'), equals('producto-stocks'));
      expect(SchemaRepository.toKebabPlural('HistorialMedico'), equals('historial-medicos'));

      // Terminaciones en consonantes (-r, -l, -n, -d)
      expect(SchemaRepository.toKebabPlural('Doctor'), equals('doctores'));
      expect(SchemaRepository.toKebabPlural('Hotel'), equals('hoteles'));
      expect(SchemaRepository.toKebabPlural('Ciudad'), equals('ciudades'));

      // Terminaciones en -s o -x
      expect(SchemaRepository.toKebabPlural('Pais'), equals('paises'));
      expect(SchemaRepository.toKebabPlural('Fax'), equals('faxes'));
    });

    test('Parses full OpenAPI 3.0 document with multiple entities, types and enums', () {
      final mockOpenApi = {
        "openapi": "3.0.1",
        "info": {"title": "Hospital Management API", "version": "1.0.0"},
        "components": {
          "schemas": {
            "PacienteRequest": {
              "type": "object",
              "required": ["nombre", "edad", "activo"],
              "properties": {
                "nombre": {"type": "string"},
                "edad": {"type": "integer", "format": "int32"},
                "peso": {"type": "number", "format": "double"},
                "activo": {"type": "boolean"},
                "tipoSangre": {
                  "type": "string",
                  "enum": ["A_POSITIVO", "O_POSITIVO", "B_NEGATIVO"]
                }
              }
            },
            "PacienteResponse": {
              "type": "object",
              "properties": {
                "id": {"type": "integer", "format": "int64"},
                "nombre": {"type": "string"}
              }
            },
            "MedicoRequest": {
              "type": "object",
              "required": ["matricula"],
              "properties": {
                "matricula": {"type": "string"},
                "especialidad": {"type": "string"}
              }
            }
          }
        }
      };

      final entities = SchemaRepository.parseOpenApiMap(mockOpenApi);

      expect(entities.length, equals(2));

      // Validación de Paciente
      final paciente = entities.firstWhere((e) => e.entityName == 'Paciente');
      expect(paciente.pluralRoute, equals('pacientes'));
      expect(paciente.fields.length, equals(5));
      expect(paciente.requiredFields, equals({'nombre', 'edad', 'activo'}));

      final tipoSangreField = paciente.findField('tipoSangre');
      expect(tipoSangreField, isNotNull);
      expect(tipoSangreField!.enumValues, contains('O_POSITIVO'));

      // Validación de Medico
      final medico = entities.firstWhere((e) => e.entityName == 'Medico');
      expect(medico.pluralRoute, equals('medicos'));
      expect(medico.fields.length, equals(2));
      expect(medico.requiredFields, contains('matricula'));
    });

    test('Gracefully handles empty schemas or schemas without Request suffix', () {
      final mockEmpty = {
        "openapi": "3.0.1",
        "components": {
          "schemas": {
            "GenericError": {
              "type": "object",
              "properties": {
                "message": {"type": "string"}
              }
            }
          }
        }
      };

      final entities = SchemaRepository.parseOpenApiMap(mockEmpty);
      expect(entities, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:umlstudio_mobile/features/schema/domain/entity_descriptor.dart';
import 'package:umlstudio_mobile/features/schema/data/schema_repository.dart';
import 'package:umlstudio_mobile/features/nlu/logic/dialog_state_machine.dart';

void main() {
  group('Schema Parser & NLU DialogStateMachine Tests', () {
    test('SchemaRepository toKebabPlural converts PascalCase correctly', () {
      expect(SchemaRepository.toKebabPlural('Usuario'), equals('usuarios'));
      expect(SchemaRepository.toKebabPlural('DetalleVenta'), equals('detalle-ventas'));
      expect(SchemaRepository.toKebabPlural('ProductoStock'), equals('producto-stocks'));
      expect(SchemaRepository.toKebabPlural('Category'), equals('categorys'));
    });

    test('OpenApiParser extracts entities, fields, and required properties', () {
      final mockOpenApi = {
        "openapi": "3.0.1",
        "components": {
          "schemas": {
            "ClienteRequest": {
              "type": "object",
              "required": ["nombre", "email"],
              "properties": {
                "nombre": {"type": "string"},
                "email": {"type": "string"},
                "telefono": {"type": "string"}
              }
            }
          }
        }
      };

      final entities = SchemaRepository.parseOpenApiMap(mockOpenApi);
      expect(entities.length, equals(1));
      expect(entities.first.entityName, equals('Cliente'));
      expect(entities.first.pluralRoute, equals('clientes'));
      expect(entities.first.fields.length, equals(3));
      expect(entities.first.requiredFields.contains('nombre'), isTrue);
      expect(entities.first.requiredFields.contains('email'), isTrue);
      expect(entities.first.requiredFields.contains('telefono'), isFalse);
    });

    test('DialogStateMachine multi-turn slot filling for required fields', () async {
      final mockEntities = [
        EntityDescriptor(
          entityName: 'Producto',
          pluralRoute: 'productos',
          requiredFields: {'nombre', 'precio'},
          fields: [
            FieldDescriptor(name: 'nombre', type: 'string', isRequired: true),
            FieldDescriptor(name: 'precio', type: 'number', isRequired: true),
            FieldDescriptor(name: 'stock', type: 'integer', isRequired: false),
          ],
        ),
      ];

      final sm = DialogStateMachine(entities: mockEntities);

      // Turno 1: Usuario da orden incompleta (solo nombre)
      final r1 = await sm.processInput("Registrar nuevo producto nombre CocaCola");
      expect(sm.isCollecting, isTrue);
      expect(r1, contains("precio"));

      // Turno 2: Usuario responde con el precio
      expect(sm.collectedSlots['nombre'], equals('CocaCola'));
      expect(sm.activeEntity?.entityName, equals('Producto'));
    });

    test('DialogStateMachine cancels dialogue when user says cancelar', () async {
      final mockEntities = [
        EntityDescriptor(
          entityName: 'Usuario',
          pluralRoute: 'usuarios',
          requiredFields: {'nombre'},
          fields: [
            FieldDescriptor(name: 'nombre', type: 'string', isRequired: true),
          ],
        ),
      ];

      final sm = DialogStateMachine(entities: mockEntities);
      await sm.processInput("Crear usuario");
      expect(sm.isCollecting, isTrue);

      final rCancel = await sm.processInput("cancelar");
      expect(sm.isCollecting, isFalse);
      expect(sm.activeEntity, isNull);
      expect(rCancel, contains("cancelada"));
    });
  });
}

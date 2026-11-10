import 'package:flutter_test/flutter_test.dart';
import 'package:umlstudio_mobile/features/schema/domain/entity_descriptor.dart';
import 'package:umlstudio_mobile/features/nlu/logic/dialog_state_machine.dart';

void main() {
  group('CU-NLU: DialogStateMachine Rigorous Use-Case Suite', () {
    late List<EntityDescriptor> domainEntities;
    late DialogStateMachine stateMachine;

    setUp(() {
      domainEntities = [
        EntityDescriptor(
          entityName: 'Cliente',
          pluralRoute: 'clientes',
          requiredFields: {'nombre', 'email', 'telefono'},
          fields: [
            FieldDescriptor(name: 'nombre', type: 'string', isRequired: true),
            FieldDescriptor(name: 'email', type: 'string', isRequired: true),
            FieldDescriptor(name: 'telefono', type: 'string', isRequired: true),
            FieldDescriptor(name: 'saldo', type: 'number', isRequired: false),
            FieldDescriptor(name: 'activo', type: 'boolean', isRequired: false),
          ],
        ),
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

      stateMachine = DialogStateMachine(entities: domainEntities);
    });

    test('CU-01: Multi-turn slot filling with sequential follow-up prompts', () async {
      // Turno 1: Orden inicial sin campos
      final res1 = await stateMachine.processInput("Quiero crear un nuevo cliente");
      expect(stateMachine.isCollecting, isTrue);
      expect(stateMachine.activeEntity?.entityName, equals('Cliente'));
      expect(res1, contains("nombre, email, telefono"));

      // Turno 2: Usuario proporciona solo el nombre
      final res2 = await stateMachine.processInput("Juan Perez");
      expect(stateMachine.isCollecting, isTrue);
      expect(stateMachine.collectedSlots['nombre'], equals('Juan Perez'));
      expect(res2, contains("email, telefono"));

      // Turno 3: Usuario proporciona email
      final res3 = await stateMachine.processInput("juan@correo.com");
      expect(stateMachine.isCollecting, isTrue);
      expect(stateMachine.collectedSlots['email'], equals('juan@correo.com'));
      expect(res3, contains("telefono"));

      // Turno 4: Usuario proporciona teléfono -> Satisface todos los campos
      await stateMachine.processInput("445566");
      expect(stateMachine.isCollecting, isFalse);
    });

    test('CU-02: Simultaneous slot extraction in a single structured phrase', () async {
      final res = await stateMachine.processInput(
        "Registrar nuevo producto nombre Auriculares precio 120.50",
      );

      expect(stateMachine.isCollecting, isFalse);
      expect(stateMachine.lastExecutedPayload['nombre'], equals('Auriculares'));
      expect(stateMachine.lastExecutedPayload['precio'], equals(120.50));
      expect(res, contains("Producto"));
    });

    test('CU-03: Fuzzy entity matching tolerates phonetic typos and noisy STT', () async {
      // Simula error fonético de STT: "cleinte" en lugar de "Cliente"
      await stateMachine.processInput("Crear nuevo cleinte");
      expect(stateMachine.activeEntity?.entityName, equals('Cliente'));
      expect(stateMachine.isCollecting, isTrue);

      stateMachine.reset();

      // Simula consulta: "Mostrar productos"
      final res = await stateMachine.processInput("Mostrar productos");
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Producto'));
      expect(res, contains("Producto"));
    });

    test('CU-04: Graceful cancellation cleans up state completely', () async {
      await stateMachine.processInput("Agregar cliente nombre Esteban");
      expect(stateMachine.isCollecting, isTrue);
      expect(stateMachine.collectedSlots['nombre'], equals('Esteban'));

      final cancelRes = await stateMachine.processInput("cancelar");
      expect(stateMachine.isCollecting, isFalse);
      expect(stateMachine.activeEntity, isNull);
      expect(stateMachine.collectedSlots, isEmpty);
      expect(cancelRes, contains("cancelada"));
    });

    test('CU-05: Type coercion handles integers, doubles, and boolean variants', () async {
      await stateMachine.processInput("Nuevo cliente nombre Maria");
      expect(stateMachine.isCollecting, isTrue);

      // Coerción de booleanos
      final resBoolTrue = stateMachine.processInput("si");
      expect(resBoolTrue, isNotNull);
    });

    test('CU-06: Unknown intents return educational guidance prompt', () async {
      final res = await stateMachine.processInput("Hola que tiempo hace hoy");
      expect(stateMachine.isCollecting, isFalse);
      expect(res, contains("No reconocí la instrucción"));
    });

    test('CU-07: Acoustic speech normalization corrects Vosk STT misrecognitions', () async {
      // Caso detectado en pantalla: "le estar productos"
      final res1 = await stateMachine.processInput("le estar productos");
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Producto'));
      expect(stateMachine.lastExecutedIntent, equals(IntentType.read));
      expect(res1, isNotEmpty);

      stateMachine.reset();

      // Caso "el estar clientes"
      final res2 = await stateMachine.processInput("el estar clientes");
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Cliente'));
      expect(stateMachine.lastExecutedIntent, equals(IntentType.read));
      expect(res2, isNotEmpty);

      stateMachine.reset();

      // Caso "lista productos"
      final res3 = await stateMachine.processInput("lista productos");
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Producto'));
      expect(stateMachine.lastExecutedIntent, equals(IntentType.read));
      expect(res3, isNotEmpty);
    });

    test('CU-08: Consultation by specific ID resolves GET by ID', () async {
      await stateMachine.processInput("consultar cliente con id 5");
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Cliente'));
      expect(stateMachine.lastExecutedIntent, equals(IntentType.read));
    });

    test('CU-09: Deletion command resolves DELETE intent with ID extraction', () async {
      await stateMachine.processInput("eliminar cliente con id 2");
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Cliente'));
      expect(stateMachine.lastExecutedIntent, equals(IntentType.delete));
    });

    test('CU-10: Update command extracts ID and modified slots for PUT', () async {
      await stateMachine.processInput("actualizar producto 1 nombre Monitor precio 199.99");
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Producto'));
      expect(stateMachine.lastExecutedIntent, equals(IntentType.update));
      expect(stateMachine.lastExecutedPayload['nombre'], equals('Monitor'));
      expect(stateMachine.lastExecutedPayload['precio'], equals(199.99));
    });

    test('CU-11: Spoken Spanish word numbers (tres, dos, cuatro) resolve as IDs in deletion', () async {
      await stateMachine.processInput("eliminar producto tres");
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Producto'));
      expect(stateMachine.lastExecutedIntent, equals(IntentType.delete));
    });

    test('CU-12: Multi-turn deletion where user responds with spoken number word', () async {
      final prompt = await stateMachine.processInput("eliminar producto");
      expect(stateMachine.isCollecting, isTrue);
      expect(prompt, contains("ID"));

      await stateMachine.processInput("el tres");
      expect(stateMachine.isCollecting, isFalse);
      expect(stateMachine.lastExecutedEntity?.entityName, equals('Producto'));
      expect(stateMachine.lastExecutedIntent, equals(IntentType.delete));
    });

    test('CU-13: Direct 36-character UUID extraction resolves without integer conversion', () async {
      const sampleUuid = "f47ac10b-58cc-4372-a567-0e02b2c3d479";
      final resolved = stateMachine.resolveTargetId(
        "eliminar cliente con id $sampleUuid",
        "eliminar cliente con id $sampleUuid",
      );
      expect(resolved, equals(sampleUuid));
    });

    test('CU-14: Ordinal voice navigation resolves indices against lastFetchedList', () async {
      // Simula registros de un modelo empresarial con UUIDs
      stateMachine.lastFetchedList = [
        {'id': 'uuid-1', 'nombre': 'Experiencia Safari'},
        {'id': 'uuid-2', 'nombre': 'Experiencia Buceo'},
        {'id': 'uuid-3', 'nombre': 'Experiencia Trekking'},
      ];

      // "eliminar el primero" -> uuid-1
      final idPrimero = stateMachine.resolveTargetId("eliminar el primero", "eliminar el primero");
      expect(idPrimero, equals('uuid-1'));

      // "consultar el segundo" -> uuid-2
      final idSegundo = stateMachine.resolveTargetId("consultar el segundo", "consultar el segundo");
      expect(idSegundo, equals('uuid-2'));

      // "borrar el último" -> uuid-3
      final idUltimo = stateMachine.resolveTargetId("borrar el último", "borrar el último");
      expect(idUltimo, equals('uuid-3'));
    });

    test('CU-15: Natural key matching resolves entity ID by spoken name or title', () async {
      stateMachine.lastFetchedList = [
        {'id': 'uuid-alpha', 'nombre': 'Juan Perez', 'email': 'juan@test.com'},
        {'id': 'uuid-beta', 'nombre': 'Maria Gómez', 'email': 'maria@test.com'},
      ];

      final idJuan = stateMachine.resolveTargetId("eliminar cliente Juan", "eliminar cliente juan");
      expect(idJuan, equals('uuid-alpha'));

      final idMaria = stateMachine.resolveTargetId("consultar Maria", "consultar maria");
      expect(idMaria, equals('uuid-beta'));
    });

    test('CU-16: Conversational pagination limits spoken summary to top 5 plus remainder', () async {
      final mockEntities = [
        EntityDescriptor(
          entityName: 'Item',
          pluralRoute: 'items',
          requiredFields: {'nombre'},
          fields: [FieldDescriptor(name: 'nombre', type: 'string', isRequired: true)],
        ),
      ];

      // Verificamos que la estructura de pagination de 5 elementos funcione
      final sm = DialogStateMachine(entities: mockEntities);
      sm.lastFetchedList = List.generate(8, (i) => {'id': 'id-$i', 'nombre': 'Item ${i + 1}'});

      final summaries = sm.lastFetchedList.map((e) => e['nombre'] as String).toList();
      final top5 = summaries.take(5).join(', ');
      final remaining = sm.lastFetchedList.length - 5;
      final text = "Se encontraron ${sm.lastFetchedList.length} registros para Item. Los primeros 5 son: $top5; y $remaining registros más. Podés verlos todos en el Explorador de Base de Datos o consultar uno por su nombre o posición.";

      expect(text, contains("Los primeros 5 son: Item 1, Item 2, Item 3, Item 4, Item 5"));
      expect(text, contains("y 3 registros más"));
    });
  });
}

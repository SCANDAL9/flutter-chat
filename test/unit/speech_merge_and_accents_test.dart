import 'package:flutter_test/flutter_test.dart';
import 'package:umlstudio_mobile/features/chat/presentation/chat_viewmodel.dart';
import 'package:umlstudio_mobile/features/nlu/logic/dialog_state_machine.dart';
import 'package:umlstudio_mobile/features/schema/domain/entity_descriptor.dart';

void main() {
  group('Speech Recognition Anti-Duplication & Utterance Merging Tests', () {
    test('Identical consecutive utterance is not duplicated', () {
      final merged = ChatViewModel.mergeUtterances('consultar materias', 'consultar materias');
      expect(merged, equals('consultar materias'));
    });

    test('Extended cumulative hypothesis replaces partial prefix without repetition', () {
      // Caso reportado: usuario dice 2 palabras ("crear materia") y luego continúa ("crear materia cálculo")
      final merged = ChatViewModel.mergeUtterances('crear materia', 'crear materia cálculo');
      expect(merged, equals('crear materia cálculo'));
      expect(merged, isNot(contains('crear materia crear materia')));
    });

    test('Late echo suffix does not append redundant words', () {
      final merged = ChatViewModel.mergeUtterances('consultar materias', 'materias');
      expect(merged, equals('consultar materias'));
    });

    test('Overlapping phrase suffixes are cleanly fused', () {
      final merged = ChatViewModel.mergeUtterances('consultar materias', 'materias con id uno');
      expect(merged, equals('consultar materias con id uno'));
    });

    test('Independent subsequent phrases are cleanly joined with space', () {
      final merged = ChatViewModel.mergeUtterances('consultar materias', 'y listar estudiantes');
      expect(merged, equals('consultar materias y listar estudiantes'));
    });
  });

  group('Diacritics and Accents Robustness Tests', () {
    test('removeDiacritics strips acute accents and umlauts cleanly', () {
      expect(DialogStateMachine.removeDiacritics('Cálculo Electrónica Módulo'), equals('Calculo Electronica Modulo'));
      expect(DialogStateMachine.removeDiacritics('año lingüística'), equals('año linguistica'));
    });

    test('Entity matching succeeds when entity has accents and user speech does not', () async {
      final entityWithAccent = EntityDescriptor(
        entityName: 'Inscripción',
        pluralRoute: 'inscripciones',
        requiredFields: {'descripción'},
        fields: [
          FieldDescriptor(name: 'id', type: 'integer', isRequired: false),
          FieldDescriptor(name: 'descripción', type: 'string', isRequired: true),
        ],
      );

      final sm = DialogStateMachine(entities: [entityWithAccent]);
      // Usuario habla sin acentos (típico de Vosk STT)
      final response = await sm.processInput('listar inscripciones');
      expect(response, isNot(contains('No reconocí la instrucción')));
    });

    test('Slot filling extracts accented character values without truncation', () async {
      final entity = EntityDescriptor(
        entityName: 'Materia',
        pluralRoute: 'materias',
        requiredFields: {'nombre', 'código'},
        fields: [
          FieldDescriptor(name: 'id', type: 'integer', isRequired: false),
          FieldDescriptor(name: 'nombre', type: 'string', isRequired: true),
          FieldDescriptor(name: 'código', type: 'string', isRequired: true),
        ],
      );

      final sm = DialogStateMachine(entities: [entity]);
      await sm.processInput('crear materia');
      expect(sm.isCollecting, isTrue);

      // Enviamos un nombre con acento y eñe en el primer turno
      await sm.processInput('Diseño de Algoritmos y Cálculo I');
      expect(sm.collectedSlots['nombre'], equals('Diseño de Algoritmos y Cálculo I'));

      // También verificamos extracción directa con regex en una sola frase
      final sm2 = DialogStateMachine(entities: [entity]);
      await sm2.processInput('crear materia nombre Matemáticas_Discretas código MAT-101');
      expect(sm2.lastExecutedPayload?['nombre'], equals('Matemáticas_Discretas'));
      expect(sm2.lastExecutedPayload?['código'], equals('MAT-101'));
    });

    test('Colloquial query speech phrases resolve read intent', () async {
      final entity = EntityDescriptor(
        entityName: 'Materia',
        pluralRoute: 'materias',
        requiredFields: {'nombre'},
        fields: [
          FieldDescriptor(name: 'id', type: 'integer', isRequired: false),
          FieldDescriptor(name: 'nombre', type: 'string', isRequired: true),
        ],
      );

      final sm = DialogStateMachine(entities: [entity]);
      expect(sm.normalizeSpeech('dame las materias'), contains('listar'));
      expect(sm.normalizeSpeech('cuáles son las materias'), contains('listar'));
      expect(sm.normalizeSpeech('traeme los estudiantes'), contains('listar'));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:umlstudio_mobile/core/theme/umlstudio_theme.dart';
import 'package:umlstudio_mobile/features/audio/data/tts_service.dart';
import 'package:umlstudio_mobile/features/audio/data/vosk_audio_service.dart';
import 'package:umlstudio_mobile/features/schema/data/schema_repository.dart';
import 'package:umlstudio_mobile/features/schema/domain/entity_descriptor.dart';
import 'package:umlstudio_mobile/features/chat/presentation/chat_viewmodel.dart';
import 'package:umlstudio_mobile/features/database/presentation/database_explorer_screen.dart';

void main() {
  group('DatabaseExplorerScreen Widget Tests', () {
    late SchemaRepository schemaRepo;
    late VoskAudioService audioService;
    late TtsService ttsService;
    late ChatViewModel viewModel;

    setUp(() {
      schemaRepo = SchemaRepository();
      audioService = VoskAudioService();
      ttsService = TtsService();
      viewModel = ChatViewModel(
        schemaRepo: schemaRepo,
        audioService: audioService,
        ttsService: ttsService,
      );

      // Inyectar entidades simuladas
      viewModel.entities = [
        EntityDescriptor(
          entityName: 'Cliente',
          pluralRoute: 'clientes',
          requiredFields: {'nombre'},
          fields: [
            FieldDescriptor(name: 'id', type: 'integer', isRequired: true),
            FieldDescriptor(name: 'nombre', type: 'string', isRequired: true),
            FieldDescriptor(name: 'edad', type: 'integer', isRequired: false),
          ],
        ),
        EntityDescriptor(
          entityName: 'Producto',
          pluralRoute: 'productos',
          requiredFields: {'nombre', 'precio'},
          fields: [
            FieldDescriptor(name: 'id', type: 'integer', isRequired: true),
            FieldDescriptor(name: 'nombre', type: 'string', isRequired: true),
            FieldDescriptor(name: 'precio', type: 'number', isRequired: true),
          ],
        ),
      ];
    });

    Widget createTestApp() {
      return MaterialApp(
        theme: UmlStudioTheme.darkTheme,
        home: ChangeNotifierProvider<ChatViewModel>.value(
          value: viewModel,
          child: const DatabaseExplorerScreen(),
        ),
      );
    }

    testWidgets('Renders all detected tables and in-place voice dock', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      // Cabecera
      expect(find.text('Explorador de Base de Datos'), findsOneWidget);
      expect(find.text('2 Tablas detectadas (OpenAPI 3.0)'), findsOneWidget);

      // Tablas dinámicas
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Producto'), findsOneWidget);

      // Atajo de voz in-situ
      expect(find.text('Comando de voz in-situ'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });
}

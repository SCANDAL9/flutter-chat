import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:umlstudio_mobile/core/theme/canvas_grid_painter.dart';
import 'package:umlstudio_mobile/core/theme/umlstudio_theme.dart';
import 'package:umlstudio_mobile/features/audio/data/tts_service.dart';
import 'package:umlstudio_mobile/features/audio/data/vosk_audio_service.dart';
import 'package:umlstudio_mobile/features/schema/data/schema_repository.dart';
import 'package:umlstudio_mobile/features/chat/presentation/chat_viewmodel.dart';
import 'package:umlstudio_mobile/features/chat/presentation/chat_screen.dart';
import 'package:umlstudio_mobile/features/chat/presentation/views/voice_live_view.dart';
import 'package:umlstudio_mobile/features/chat/presentation/widgets/fluid_voice_orb.dart';
import 'package:umlstudio_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';

void main() {
  group('ChatScreen & VoiceLiveView Widget Integration Tests', () {
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
    });

    Widget createTestApp() {
      return MaterialApp(
        theme: UmlStudioTheme.darkTheme,
        home: ChangeNotifierProvider<ChatViewModel>.value(
          value: viewModel,
          child: const ChatScreen(),
        ),
      );
    }

    testWidgets('Renders Voice-First Gemini Live UI by default', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      // Verifica componente VoiceLiveView y FluidVoiceOrb activos
      expect(find.byType(VoiceLiveView), findsOneWidget);
      expect(find.byType(FluidVoiceOrb), findsOneWidget);
      expect(find.text('UmlStudio Live'), findsOneWidget);

      // Botón para cambiar a modo chat
      expect(find.text('Modo Chat'), findsOneWidget);

      // Verifica fondo con CustomPaint CanvasGridPainter
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is CanvasGridPainter,
        ),
        findsOneWidget,
      );

      // Botón living mic activo
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('Toggling to Chat Mode shows traditional input dock and message list', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      // Tocar en "Modo Chat"
      await tester.tap(find.text('Modo Chat'));
      await tester.pump(const Duration(milliseconds: 200));

      // Ahora estamos en modo Chat tradicional
      expect(find.text('UmlStudio Chat'), findsOneWidget);
      expect(find.text('Voz en Vivo'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      // Ingresar texto y enviar
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Listar productos');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 200));

      // Debe aparecer la burbuja del usuario
      expect(
        find.descendant(of: find.byType(ChatMessageBubble), matching: find.text('Listar productos')),
        findsOneWidget,
      );
      expect(find.byType(ChatMessageBubble), findsWidgets);
    });

    testWidgets('Tapping TTS icon in AppBar toggles speech synthesis', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Chat mode where the TTS toggle icon is in the AppBar
      await tester.tap(find.text('Modo Chat'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(viewModel.ttsService.isEnabled, isTrue);

      final ttsButton = find.byTooltip('Voz (TTS)');
      await tester.tap(ttsButton);
      await tester.pump(const Duration(milliseconds: 200));

      expect(viewModel.ttsService.isEnabled, isFalse);
    });
  });
}

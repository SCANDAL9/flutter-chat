import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/umlstudio_theme.dart';
import 'features/audio/data/tts_service.dart';
import 'features/audio/data/vosk_audio_service.dart';
import 'features/schema/data/schema_repository.dart';
import 'features/chat/presentation/chat_viewmodel.dart';
import 'features/chat/presentation/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UmlStudioMobileApp());
}

class UmlStudioMobileApp extends StatelessWidget {
  const UmlStudioMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SchemaRepository>(
          create: (_) => SchemaRepository(baseUrl: 'http://localhost:8080'),
        ),
        Provider<VoskAudioService>(
          create: (_) => VoskAudioService(),
        ),
        Provider<TtsService>(
          create: (_) => TtsService(),
        ),
        ChangeNotifierProvider<ChatViewModel>(
          create: (ctx) => ChatViewModel(
            schemaRepo: ctx.read<SchemaRepository>(),
            audioService: ctx.read<VoskAudioService>(),
            ttsService: ctx.read<TtsService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'UmlStudio Mobile',
        debugShowCheckedModeBanner: false,
        theme: UmlStudioTheme.darkTheme,
        home: const ChatScreen(),
      ),
    );
  }
}

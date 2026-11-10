import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/umlstudio_tokens.dart';
import '../../../../core/theme/canvas_grid_painter.dart';
import 'chat_viewmodel.dart';
import 'views/voice_live_view.dart';
import 'widgets/chat_message_bubble.dart';
import '../../database/presentation/database_explorer_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatViewModel>().init();
    });
  }

  void _sendMessage(ChatViewModel vm, String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    vm.sendUserMessage(clean);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();

    // PRIORIDAD VOZ (Gemini Live Mode)
    if (vm.isVoiceLiveMode) {
      return VoiceLiveView(vm: vm);
    }

    // MODO CHAT TRADICIONAL ULTRA-MODERNO
    return Scaffold(
      backgroundColor: const Color(0xFF070A11), // Deepest Void Obsidian
      resizeToAvoidBottomInset: true,
      appBar: _buildModernAppBar(context, vm),
      body: Stack(
        children: [
          // 1. Fondo de cuadrícula técnica
          Positioned.fill(
            child: Opacity(
              opacity: 0.70,
              child: CustomPaint(
                painter: CanvasGridPainter(),
              ),
            ),
          ),

          // 2. Columna de conversación y entrada de datos
          Column(
            children: [
              if (vm.isLoading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(UmlStudioTokens.dodgerBlue),
                ),

              // Lista de mensajes fluida orientada al fondo (reverse: true)
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Fix: ancla automáticamente al fondo sin jitter de scroll
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: vm.messages.length,
                    itemBuilder: (context, index) {
                      // Con reverse: true, el índice 0 es el mensaje más reciente
                      final reversedIndex = vm.messages.length - 1 - index;
                      final msg = vm.messages[reversedIndex];
                      return ChatMessageBubble(message: msg);
                    },
                  ),
                ),
              ),

              // Muelle de entrada de texto moderno flotante
              _buildModernInputDock(vm),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(BuildContext context, ChatViewModel vm) {
    return AppBar(
      backgroundColor: const Color(0xFF0C1322).withValues(alpha: 0.90),
      elevation: 0,
      titleSpacing: 12,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: Colors.transparent),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: UmlStudioTokens.deepSkyBlue),
          tooltip: "Volver a Modo Voz en Vivo",
          onPressed: vm.toggleVoiceLiveMode,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "UmlStudio Chat",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: UmlStudioTokens.darkForeground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            vm.entities.isNotEmpty ? "8080 • ${vm.entities.length} Entidades" : vm.statusMessage,
            style: TextStyle(
              fontSize: 11,
              color: vm.entities.isNotEmpty ? UmlStudioTokens.success : UmlStudioTokens.darkTextMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        // Botón elegante para regresar a Voz en Vivo
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: UmlStudioTokens.dodgerBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
              ),
            ),
            icon: const Icon(Icons.mic_rounded, size: 15),
            label: const Text(
              "Voz en Vivo",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            onPressed: vm.toggleVoiceLiveMode,
          ),
        ),
        const SizedBox(width: 4),

        // Botón Explorador de Base de Datos
        IconButton(
          icon: const Icon(Icons.table_chart_rounded, color: UmlStudioTokens.deepSkyBlue, size: 20),
          tooltip: "Explorador de Base de Datos",
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DatabaseExplorerScreen()),
            );
          },
        ),
        const SizedBox(width: 4),

        // Botón de TTS
        IconButton(
          icon: Icon(
            vm.ttsService.isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: vm.ttsService.isEnabled ? UmlStudioTokens.deepSkyBlue : UmlStudioTokens.darkTextMuted,
            size: 20,
          ),
          tooltip: "Voz (TTS)",
          onPressed: vm.toggleTts,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildModernInputDock(ChatViewModel vm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1322).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vm.isListening)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: UmlStudioTokens.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                  border: Border.all(
                    color: UmlStudioTokens.danger.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(UmlStudioTokens.danger),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        vm.currentPartialSpeech.isNotEmpty
                            ? "Escuchando: ${vm.currentPartialSpeech}"
                            : "Escuchando audio... Habla ahora",
                        style: const TextStyle(
                          fontSize: 12,
                          color: UmlStudioTokens.danger,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Cápsula de entrada flotante redondeada
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131D30),
                borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  // Botón de Micrófono
                  IconButton(
                    icon: Icon(
                      vm.isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                      color: vm.isListening ? UmlStudioTokens.danger : UmlStudioTokens.deepSkyBlue,
                      size: 24,
                    ),
                    tooltip: "Reconocimiento de voz",
                    onPressed: vm.toggleListening,
                  ),

                  // Campo de texto
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: UmlStudioTokens.darkForeground,
                        fontSize: 14.5,
                      ),
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: "Escribe una instrucción o consulta...",
                        hintStyle: TextStyle(
                          color: UmlStudioTokens.darkTextMuted,
                          fontSize: 14,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      ),
                      onSubmitted: (val) => _sendMessage(vm, val),
                    ),
                  ),

                  // Botón enviar
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                      onTap: () => _sendMessage(vm, _textController.text),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: UmlStudioTokens.dodgerBlue.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/umlstudio_tokens.dart';
import '../../../../core/theme/canvas_grid_painter.dart';
import '../chat_viewmodel.dart';
import '../widgets/fluid_voice_orb.dart';
import '../../../database/presentation/database_explorer_screen.dart';

class VoiceLiveView extends StatelessWidget {
  final ChatViewModel vm;

  const VoiceLiveView({super.key, required this.vm});

  String _getStatusHeadline() {
    if (vm.isAssistantSpeaking) return "Respondiendo...";
    if (vm.isProcessing) return "Consultando OpenAPI...";
    if (vm.isListening) return "Te escucho...";
    return "Toca el orbe para hablar";
  }

  Color _getStatusAccent() {
    if (vm.isAssistantSpeaking) return const Color(0xFF10B981);
    if (vm.isProcessing) return const Color(0xFF8B5CF6);
    if (vm.isListening) return const Color(0xFF38BDF8);
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _getStatusAccent();

    return Scaffold(
      backgroundColor: const Color(0xFF070A11), // Deepest Void Obsidian
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Fondo de cuadrícula técnica atenuada
          Positioned.fill(
            child: Opacity(
              opacity: 0.75,
              child: CustomPaint(
                painter: CanvasGridPainter(),
              ),
            ),
          ),

          // 2. Resplandor ambiental de fondo (Dynamic Backdrop Bloom)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.18,
            left: MediaQuery.of(context).size.width * 0.1,
            right: MediaQuery.of(context).size.width * 0.1,
            height: 340,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: vm.isListening || vm.isAssistantSpeaking ? 0.22 : 0.06),
                    accent.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.2, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 3. Estructura principal inmersiva
          SafeArea(
            child: Column(
              children: [
                // Barra superior flotante de cristal esmerilado
                _buildFloatingTopBar(context),

                // Contenido interactivo central con scroll elástico
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),

                        // Título y estado minimalista
                        _buildStatusHeader(accent),

                        const SizedBox(height: 20),

                        // El Orbe de Voz fluido y orgánico
                        GestureDetector(
                          onTap: vm.toggleListening,
                          child: FluidVoiceOrb(
                            isListening: vm.isListening,
                            isSpeaking: vm.isAssistantSpeaking,
                            isProcessing: vm.isProcessing,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Transcripción en vivo (subtítulos fluidos)
                        _buildSpeechTranscriptionSection(accent),

                        const SizedBox(height: 16),

                        // Tarjeta de respuesta del Asistente en cristal esmerilado
                        _buildAssistantGlassCard(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Muelle de controles flotantes (Ergonomía Gemini Live)
                _buildFloatingControlDock(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Píldora de estado de conexión NLU flexible
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: vm.entities.isNotEmpty ? UmlStudioTokens.success : UmlStudioTokens.danger,
                          boxShadow: [
                            BoxShadow(
                              color: (vm.entities.isNotEmpty ? UmlStudioTokens.success : UmlStudioTokens.danger)
                                  .withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "UmlStudio Live",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: UmlStudioTokens.darkForeground,
                        ),
                      ),
                      if (vm.entities.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "• ${vm.entities.length} Entidades",
                            style: const TextStyle(
                              fontSize: 11,
                              color: UmlStudioTokens.darkTextMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Acciones de cabecera: Explorador de BD, TTS y Cambio a Chat
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón rápido Explorador de BD
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 1.0,
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.table_chart_rounded, size: 17, color: UmlStudioTokens.deepSkyBlue),
                      tooltip: "Base de Datos",
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DatabaseExplorerScreen()),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón rápido TTS (Mute/Unmute)
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 1.0,
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        vm.ttsService.isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        size: 18,
                        color: vm.ttsService.isEnabled ? UmlStudioTokens.deepSkyBlue : UmlStudioTokens.darkTextMuted,
                      ),
                      tooltip: "Audio TTS",
                      onPressed: vm.toggleTts,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón conmutable "Modo Chat"
              ClipRRect(
                borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                      onTap: vm.toggleVoiceLiveMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: UmlStudioTokens.dodgerBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                          border: Border.all(
                            color: UmlStudioTokens.dodgerBlue.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 14, color: UmlStudioTokens.deepSkyBlue),
                            SizedBox(width: 6),
                            Text(
                              "Modo Chat",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: UmlStudioTokens.deepSkyBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(Color accent) {
    return Column(
      children: [
        Text(
          _getStatusHeadline(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: UmlStudioTokens.darkForeground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                vm.isListening ? "Escuchando voz continua (Vosk Offline)" : "Toca el botón o el orbe para hablar",
                style: const TextStyle(
                  fontSize: 12,
                  color: UmlStudioTokens.darkTextMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeechTranscriptionSection(Color accent) {
    final text = vm.currentPartialSpeech.isNotEmpty
        ? vm.currentPartialSpeech
        : (vm.lastUserCommandText != null ? vm.lastUserCommandText! : "");

    if (text.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(UmlStudioTokens.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(UmlStudioTokens.radiusLg),
            border: Border.all(
              color: vm.currentPartialSpeech.isNotEmpty
                  ? accent.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    vm.currentPartialSpeech.isNotEmpty ? Icons.graphic_eq_rounded : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vm.currentPartialSpeech.isNotEmpty ? "TRANSCRIPCIÓN EN VIVO" : "ORDEN DE VOZ PROCESADA",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "“$text”",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: vm.currentPartialSpeech.isNotEmpty
                      ? Colors.white
                      : UmlStudioTokens.darkForeground,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantGlassCard() {
    final text = vm.lastSpokenAssistantText.isNotEmpty
        ? vm.lastSpokenAssistantText
        : "Sistema listo. Los cambios y consultas se ejecutan directamente sobre la API OpenAPI de UmlStudio.";

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF101726).withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: UmlStudioTokens.dodgerBlue.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 14, color: UmlStudioTokens.deepSkyBlue),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "ASISTENTE UMLSTUDIO",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: UmlStudioTokens.darkTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: UmlStudioTokens.darkForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingControlDock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. Botón secundario izquierdo: Abrir Teclado / Chat
                _buildCircularAction(
                  icon: Icons.keyboard_alt_outlined,
                  tooltip: "Escribir texto",
                  onTap: vm.toggleVoiceLiveMode,
                ),

                // 2. Botón principal central gigante: Micrófono / Detener
                _buildLivingMicButton(),

                // 3. Botón secundario derecho: Cancelar / Sincronizar
                _buildCircularAction(
                  icon: vm.stateMachine?.isCollecting == true
                      ? Icons.close_rounded
                      : Icons.refresh_rounded,
                  tooltip: vm.stateMachine?.isCollecting == true ? "Cancelar" : "Sincronizar",
                  onTap: vm.stateMachine?.isCollecting == true
                      ? vm.cancelCurrentOperation
                      : vm.init,
                  color: vm.stateMachine?.isCollecting == true ? UmlStudioTokens.danger : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLivingMicButton() {
    final isListening = vm.isListening;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
        onTap: vm.toggleListening,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isListening
                  ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                  : const [Color(0xFF38BDF8), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isListening ? const Color(0xFFEF4444) : const Color(0xFF38BDF8))
                    .withValues(alpha: 0.50),
                blurRadius: 22,
                spreadRadius: 3,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 2.0,
            ),
          ),
          child: Icon(
            isListening ? Icons.stop_rounded : Icons.mic_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1.0,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: color ?? UmlStudioTokens.darkForeground,
          ),
        ),
      ),
    );
  }
}

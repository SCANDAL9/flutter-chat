import 'dart:math';
import 'package:flutter/material.dart';

class FluidVoiceOrb extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final bool isProcessing;

  const FluidVoiceOrb({
    super.key,
    required this.isListening,
    required this.isSpeaking,
    required this.isProcessing,
  });

  @override
  State<FluidVoiceOrb> createState() => _FluidVoiceOrbState();
}

class _FluidVoiceOrbState extends State<FluidVoiceOrb> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  List<Color> _getGradientColors() {
    if (widget.isSpeaking) {
      // Emerald / Cyan radiant aurora
      return const [
        Color(0xFF34D399),
        Color(0xFF059669),
        Color(0xFF0E7490),
        Color(0xFF0F172A),
      ];
    }
    if (widget.isProcessing) {
      // Cosmic Violet / Indigo / Cyan
      return const [
        Color(0xFFA78BFA),
        Color(0xFF6366F1),
        Color(0xFF3B82F6),
        Color(0xFF0F172A),
      ];
    }
    if (widget.isListening) {
      // Gemini signature Electric Cyan / Dodger Blue / Deep Cobalt
      return const [
        Color(0xFF38BDF8),
        Color(0xFF3590F3),
        Color(0xFF1D4ED8),
        Color(0xFF0B132B),
      ];
    }
    // Idle / Deep Obsidian Luminescence
    return const [
      Color(0xFF334155),
      Color(0xFF1E293B),
      Color(0xFF0F172A),
      Color(0xFF090D16),
    ];
  }

  Color _getPrimaryAccent() {
    if (widget.isSpeaking) return const Color(0xFF10B981);
    if (widget.isProcessing) return const Color(0xFF8B5CF6);
    if (widget.isListening) return const Color(0xFF38BDF8);
    return const Color(0xFF475569);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors();
    final accent = _getPrimaryAccent();
    final isActive = widget.isListening || widget.isSpeaking || widget.isProcessing;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _waveController]),
      builder: (context, child) {
        final pulse = _pulseAnimation.value;
        final waveValue = _waveController.value;

        return SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Capa de resplandor ambiental exterior (Ambient Bloom)
              if (isActive)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.28 + (pulse * 0.18)),
                          accent.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),

              // 2. Ondas armónicas expansivas de audio (Harmonic Ripples)
              if (isActive)
                CustomPaint(
                  size: const Size(260, 260),
                  painter: _OrbWaveRipplesPainter(
                    waveProgress: waveValue,
                    color: accent,
                    pulseFactor: pulse,
                  ),
                ),

              // 3. Orbe principal fluido con degradado multidimensional
              Transform.scale(
                scale: isActive ? 1.0 + (pulse * 0.07) : 1.0,
                child: Container(
                  width: 172,
                  height: 172,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment(-0.6 + cos(waveValue * 2 * pi) * 0.3, -1.0),
                      end: Alignment(0.8, 1.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: isActive ? 0.45 : 0.15),
                        blurRadius: isActive ? 36 : 18,
                        spreadRadius: isActive ? 8 : 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isActive ? 0.35 : 0.12),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        // Brillo especular superior estilo vidrio líquido
                        Positioned(
                          top: -30,
                          left: -20,
                          width: 160,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Espectro de ondas sonoras dinámicas internas
                        Center(
                          child: CustomPaint(
                            size: const Size(120, 60),
                            painter: _InternalVoiceWavePainter(
                              progress: waveValue,
                              pulse: pulse,
                              isActive: isActive,
                              isSpeaking: widget.isSpeaking,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrbWaveRipplesPainter extends CustomPainter {
  final double waveProgress;
  final Color color;
  final double pulseFactor;

  _OrbWaveRipplesPainter({
    required this.waveProgress,
    required this.color,
    required this.pulseFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (waveProgress + (i / 3.0)) % 1.0;
      final currentRadius = 90.0 + (ringProgress * (maxRadius - 90.0));
      final opacity = (1.0 - ringProgress) * (0.28 + (pulseFactor * 0.15));

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 - (ringProgress * 0.8);

      canvas.drawCircle(center, currentRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbWaveRipplesPainter oldDelegate) => true;
}

class _InternalVoiceWavePainter extends CustomPainter {
  final double progress;
  final double pulse;
  final bool isActive;
  final bool isSpeaking;
  final Color color;

  _InternalVoiceWavePainter({
    required this.progress,
    required this.pulse,
    required this.isActive,
    required this.isSpeaking,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) {
      // Línea minimalista en reposo con punto central
      final paint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.25, size.height / 2),
        Offset(size.width * 0.75, size.height / 2),
        paint,
      );
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        3.5,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final barCount = 7;
    final spacing = size.width / (barCount + 1);

    for (int i = 0; i < barCount; i++) {
      final x = spacing * (i + 1);
      final phase = (i * 0.75) + (progress * 2 * pi);
      final amplitude = (isSpeaking ? 22.0 : 16.0) * (0.35 + (sin(phase).abs() * 0.65));
      final height = 6.0 + amplitude * (0.8 + (pulse * 0.4));

      final barPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.45),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x - 2, (size.height - height) / 2, 4, height))
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.6;

      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InternalVoiceWavePainter oldDelegate) => true;
}

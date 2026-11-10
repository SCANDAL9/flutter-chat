import 'package:flutter/material.dart';
import 'umlstudio_tokens.dart';

class CanvasGridPainter extends CustomPainter {
  final double spacing;
  final double dotRadius;
  final Color dotColor;

  CanvasGridPainter({
    this.spacing = 28.0,
    this.dotRadius = 1.0,
    this.dotColor = UmlStudioTokens.darkGridDot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasGridPainter oldDelegate) {
    return oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.dotColor != dotColor;
  }
}

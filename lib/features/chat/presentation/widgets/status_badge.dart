import 'package:flutter/material.dart';
import '../../../../core/theme/umlstudio_tokens.dart';

class StatusBadge extends StatelessWidget {
  final bool isConnected;
  final int entityCount;
  final String statusText;
  final VoidCallback onRefresh;

  const StatusBadge({
    super.key,
    required this.isConnected,
    required this.entityCount,
    required this.statusText,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected
            ? UmlStudioTokens.darkSurfaceSunken
            : UmlStudioTokens.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
        border: Border.all(
          color: isConnected
              ? UmlStudioTokens.darkBorder
              : UmlStudioTokens.danger.withValues(alpha: 0.4),
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
              color: isConnected ? UmlStudioTokens.success : UmlStudioTokens.danger,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? UmlStudioTokens.success : UmlStudioTokens.danger)
                      .withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? "$entityCount Entidades" : "Desconectado",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isConnected
                  ? UmlStudioTokens.darkTextSecondary
                  : UmlStudioTokens.danger,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/umlstudio_tokens.dart';
import '../chat_viewmodel.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  bool _isSlotPrompt(String text) {
    return text.contains("¿Cuál es el valor") || text.contains("campo obligatorio");
  }

  bool _isSuccessMessage(String text) {
    return text.contains("exitosamente") || text.contains("Se encontraron");
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isPrompt = !isUser && _isSlotPrompt(message.text);
    final isSuccess = !isUser && _isSuccessMessage(message.text);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? null
              : (isPrompt
                  ? const Color(0xFF1E1B4B).withValues(alpha: 0.85) // Subtle indigo-violet for prompts
                  : const Color(0xFF131D2F).withValues(alpha: 0.90)),
          gradient: isUser
              ? const LinearGradient(
                  colors: [
                    Color(0xFF3590F3),
                    Color(0xFF1D4ED8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(
            color: isUser
                ? Colors.white.withValues(alpha: 0.25)
                : (isPrompt
                    ? const Color(0xFF818CF8).withValues(alpha: 0.50)
                    : (isSuccess
                        ? UmlStudioTokens.success.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.08))),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? UmlStudioTokens.dodgerBlue.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPrompt
                          ? const Color(0xFF818CF8).withValues(alpha: 0.2)
                          : UmlStudioTokens.dodgerBlue.withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      isPrompt ? Icons.help_outline_rounded : Icons.auto_awesome,
                      size: 11,
                      color: isPrompt ? const Color(0xFFA5B4FC) : UmlStudioTokens.deepSkyBlue,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isPrompt ? "SOLICITUD DE DATO" : "UMLSTUDIO ASISTENTE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isPrompt ? const Color(0xFFA5B4FC) : UmlStudioTokens.deepSkyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : UmlStudioTokens.darkForeground,
                fontSize: 14.5,
                height: 1.45,
                fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: isUser
                    ? Colors.white.withValues(alpha: 0.65)
                    : UmlStudioTokens.darkTextMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

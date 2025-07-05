import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../model/message.dart';

class ChatBubble extends StatelessWidget {
  final Message message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final hasImage = message.imagePath != null;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 18 : 0),
            topRight: const Radius.circular(18),
            bottomLeft: const Radius.circular(18),
            bottomRight: Radius.circular(isUser ? 0 : 18),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 18 : 0),
                  topRight: const Radius.circular(18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: Radius.circular(isUser ? 0 : 18),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (message.text != null && message.text!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message.text!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style:
                    const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

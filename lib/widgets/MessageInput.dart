import 'package:flutter/material.dart';
import '../widgets/appColors.dart';

class MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final Animation<double> buttonAnimation;
  final VoidCallback onMicTap;
  final VoidCallback onSendTap;
  final VoidCallback onAttachTap;
  final ValueChanged<String> onSubmitted;

  const MessageInputBar({
    super.key,
    required this.controller,
    required this.hasText,
    required this.buttonAnimation,
    required this.onMicTap,
    required this.onSendTap,
    required this.onAttachTap,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGradient[1],
        border: const Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: onSubmitted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: hasText ? onSendTap : onMicTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasText ? AppColors.botGradient : AppColors.userGradient,
                ),
                shape: BoxShape.circle,
              ),
              child: AnimatedBuilder(
                animation: buttonAnimation,
                builder: (context, _) => Transform.scale(
                  scale: 0.9 + buttonAnimation.value * 0.1,
                  child: Icon(hasText ? Icons.send : Icons.mic, color: Colors.white),
                ),
              ),
            ),
          ),
          // GestureDetector(
          //   onTap: onAttachTap,
          //   child: Container(
          //     width: 50,
          //     height: 50,
          //     margin: const EdgeInsets.only(left: 8),
          //     decoration: BoxDecoration(
          //       gradient: LinearGradient(colors: AppColors.botGradient),
          //       shape: BoxShape.circle,
          //     ),
          //     child: const Icon(Icons.add, color: Colors.white),
          //   ),
          // ),
        ],
      ),
    );
  }
}

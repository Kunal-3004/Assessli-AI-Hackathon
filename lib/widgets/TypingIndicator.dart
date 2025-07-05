import 'dart:ui';
import 'package:flutter/material.dart';

class TypingIndicator extends StatelessWidget {
  final Animation<double> animation;

  const TypingIndicator({Key? key, required this.animation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return Container(
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: ((animation.value + i * 0.3) % 1.0),
                          child: child,
                        );
                      },
                      child: const SizedBox.shrink(),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

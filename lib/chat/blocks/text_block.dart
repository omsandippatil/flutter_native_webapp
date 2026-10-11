
import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';

class TextBlock extends StatelessWidget {
  const TextBlock({
    super.key,
    required this.text,
    required this.isUser,
    this.isMuted = false,
    this.showSpeakerIcon = false,
  });

  final String text;
  final bool isUser;
  final bool isMuted;
  final bool showSpeakerIcon;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? AppTheme.userBubble : AppTheme.chatBubble,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Text(
        text,
        style: AppTheme.text(
          size: 15,
          height: 1.45,
          color: isMuted ? AppTheme.subheadingColor : AppTheme.textColor,
        ),
      ),
    );
  }
} 
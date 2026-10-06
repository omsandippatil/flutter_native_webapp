import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';
import 'package:tapapp/features/classroom/application/classroom_session_controller.dart';
import 'package:tapapp/features/classroom/models/classroom_message.dart';
import 'package:tapapp/features/classroom/presentation/widgets/chat/message_content.dart';

class ClassChatBubbleRow extends StatelessWidget {
  const ClassChatBubbleRow({
    super.key,
    required this.message,
    required this.controller,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final isUser = message.sender == ClassChatSender.user;

    if (message.contentType == ClassChatContentType.loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: scale.md),
        child: const Center(child: _TypingIndicator()),
      );
    }

    if (message.contentType == ClassChatContentType.checkpoint) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: scale.sm),
        child: ClassCheckpointCard(message: message, controller: controller),
      );
    }

    if (isUser) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: scale.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(context).width * 0.72)
                      .clamp(0.0, scale.userBubbleMaxWidth),
                ),
                child: ClassMessageContent(
                  message: message,
                  controller: controller,
                  isUser: true,
                ),
              ),
            ),
            SizedBox(width: scale.xs),
            _ClassAvatar(isUser: true, size: scale.avatarSize),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: scale.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ClassAvatar(isUser: false, size: scale.avatarSize),
          SizedBox(width: scale.xs),
          Expanded(
            child: ClassMessageContent(
              message: message,
              controller: controller,
              isUser: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassAvatar extends StatelessWidget {
  const _ClassAvatar({required this.isUser, required this.size});

  final bool isUser;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(
          Icons.person_rounded,
          size: size * 0.53,
          color: AppTheme.buttonColor,
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppTheme.classroomMessageSurface,
      child: ClipOval(
        child: Image.asset(
          'assets/images/branding/tap_buddy_pp.png',
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.smart_toy_rounded,
            size: size * 0.53,
            color: AppTheme.cardBackground,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: scale.md, vertical: scale.sm),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: SizedBox(
        width: 40,
        height: 16,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(3, (i) {
                final t = (_controller.value + (i * 0.2)) % 1.0;
                final scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scale,
                  child: const CircleAvatar(
                    radius: 3,
                    backgroundColor: AppTheme.imagePlaceholder,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
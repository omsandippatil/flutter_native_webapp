import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';

class RevealState {
  const RevealState({
    required this.progress,
    this.title = "Today's picture",
    required this.assetPath,
    this.lockedMessage =
        'Complete the activity to reveal the secret character hiding behind the cloud! ☁️✨',
    this.unlockedMessage =
        "Congratulations !!🎉 You have unlocked today's picture",
  });

  final double progress;
  final String title;
  final String assetPath;
  final String lockedMessage;
  final String unlockedMessage;

  bool get revealed => progress >= 1;

  String get message => revealed ? unlockedMessage : lockedMessage;

  RevealState copyWith({
    double? progress,
    String? title,
    String? assetPath,
    String? lockedMessage,
    String? unlockedMessage,
  }) => RevealState(
    progress: progress ?? this.progress,
    title: title ?? this.title,
    assetPath: assetPath ?? this.assetPath,
    lockedMessage: lockedMessage ?? this.lockedMessage,
    unlockedMessage: unlockedMessage ?? this.unlockedMessage,
  );
}

class CloudRevealPainter extends CustomPainter {
  const CloudRevealPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final coverWidth = size.width * (1 - progress.clamp(0.0, 1.0));
    final centerX = size.width / 2;
    final centerY = size.height * 0.48;

    canvas.drawCircle(Offset(centerX, centerY), coverWidth * 0.42, paint);
    canvas.drawCircle(
      Offset(centerX - coverWidth * 0.18, centerY + 8),
      coverWidth * 0.32,
      paint,
    );
    canvas.drawCircle(
      Offset(centerX + coverWidth * 0.18, centerY + 6),
      coverWidth * 0.34,
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, centerY + 20),
        width: coverWidth * 0.82,
        height: coverWidth * 0.34,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CloudRevealPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class RevealImage extends StatelessWidget {
  const RevealImage({super.key, required this.state, required this.height});

  final RevealState state;
  final double height;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            height: height,
            color: AppTheme.revealBackground,
          ),
          Image.asset(
            state.assetPath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            errorBuilder: (context, error, stackTrace) => Container(
              height: height,
              color: AppTheme.classroomMessageSurface,
              child: const Icon(
                Icons.image_rounded,
                size: 40,
                color: AppTheme.imagePlaceholder,
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: (1 - progress).clamp(0.0, 1.0),
              duration: const Duration(milliseconds: 500),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 7 * (1 - progress),
                  sigmaY: 7 * (1 - progress),
                ),
                child: Container(color: Colors.white.withValues(alpha: 0)),
              ),
            ),
          ),
          if (progress < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: CloudRevealPainter(
                    progress: progress,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          if (progress < 0.95)
            Text(
              '???',
              style: AppTheme.text(
                size: 34,
                weight: FontWeight.w900,
                color: AppTheme.stemText,
              ).copyWith(
                shadows: const [
                  Shadow(
                    color: Colors.white,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
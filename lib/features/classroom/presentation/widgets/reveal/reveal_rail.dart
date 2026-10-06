import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tapapp/core/router/app_router.dart';
import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';
import 'package:tapapp/domain/learner/providers/learner_state_providers.dart';
import 'package:tapapp/features/classroom/application/classroom_session_controller.dart';
import 'package:tapapp/features/classroom/presentation/widgets/reveal/reveal_asset_resolver.dart';
import 'package:tapapp/features/home/models/learning_dashboard.dart';

class ClassPendingActivityChoiceBody extends StatelessWidget {
  const ClassPendingActivityChoiceBody({
    super.key,
    required this.unit,
    required this.onStart,
    required this.onMaybeLater,
  });

  final CourseUnit unit;
  final VoidCallback onStart;
  final VoidCallback onMaybeLater;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(scale.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Text(
                  'Want to continue?',
                  textAlign: TextAlign.center,
                  style: AppTheme.text(size: 24, weight: FontWeight.w800),
                ),
                SizedBox(height: scale.xs),
                Text(
                  'Start the next activity when you are ready.',
                  textAlign: TextAlign.center,
                  style: AppTheme.text(size: 14, color: AppTheme.subheadingColor),
                ),
                SizedBox(height: scale.xl),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(scale.md),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: Image.asset(
                          unit.thumbnailAsset,
                          width: 112,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 112,
                            height: 96,
                            color: AppTheme.classroomMessageSurface,
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppTheme.buttonColor,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: scale.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.courseDisplay,
                              style: AppTheme.text(
                                size: 12,
                                color: AppTheme.imagePlaceholder,
                              ),
                            ),
                            SizedBox(height: scale.xxs),
                            Text(
                              unit.unitName,
                              style: AppTheme.text(size: 17, weight: FontWeight.w800),
                            ),
                            SizedBox(height: scale.xs + 2),
                            _EarnRow(
                              icon: Icons.stars_rounded,
                              iconColor: AppTheme.warningIcon,
                              label: '${unit.totalPoints} Points',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: scale.md),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: scale.buttonHeight,
                        child: ElevatedButton(
                          onPressed: onStart,
                          style: AppTheme.primaryButtonStyle(),
                          child: const Text("Let's go"),
                        ),
                      ),
                    ),
                    SizedBox(width: scale.xs + 2),
                    Expanded(
                      child: SizedBox(
                        height: scale.buttonHeight,
                        child: OutlinedButton(
                          onPressed: onMaybeLater,
                          child: const Text('Maybe later'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClassNextActivityInlineCard extends ConsumerWidget {
  const ClassNextActivityInlineCard({
    super.key,
    required this.controller,
    required this.onStartNextActivity,
  });

  final ClassChatController controller;
  final VoidCallback onStartNextActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = AppSpacing.of(context);

    if (!controller.hasNextUnit) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: scale.xs),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(scale.lg),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              Text(
                'Course complete! 🎉',
                style: AppTheme.text(size: 18, weight: FontWeight.w800),
              ),
              SizedBox(height: scale.xs),
              Text(
                'You completed every activity in this course.',
                textAlign: TextAlign.center,
                style: AppTheme.text(size: 14, color: AppTheme.subheadingColor),
              ),
              SizedBox(height: scale.md),
              SizedBox(
                width: double.infinity,
                height: scale.buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    ref.invalidate(
                      learnerStateDataProvider(controller.learnerId),
                    );
                    context.go(AppRoutes.home);
                  },
                  style: AppTheme.primaryButtonStyle(),
                  child: const Text('Back to home'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isWide = scale.showsSideRail;
    final previewWidth = isWide ? 200.0 : 96.0;
    final previewHeight = isWide ? 160.0 : 96.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: scale.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: scale.sm, vertical: scale.xs + 2),
            decoration: BoxDecoration(
              color: AppTheme.classroomMessageSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Watch another video?',
                  style: AppTheme.text(size: 13, color: AppTheme.subheadingColor),
                ),
                SizedBox(width: scale.xs),
                const Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: AppTheme.buttonColor,
                ),
              ],
            ),
          ),
          SizedBox(height: scale.sm),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(scale.md),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    width: previewWidth,
                    height: previewHeight,
                    color: AppTheme.classroomMessageSurface,
                    child: const Icon(
                      Icons.image_rounded,
                      size: 30,
                      color: AppTheme.imagePlaceholder,
                    ),
                  ),
                ),
                SizedBox(width: scale.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.courseDisplay,
                        style: AppTheme.text(
                          size: 12,
                          color: AppTheme.imagePlaceholder,
                        ),
                      ),
                      SizedBox(height: scale.xxs),
                      Text(
                        controller.nextUnitName,
                        style: AppTheme.text(size: 16, weight: FontWeight.w800),
                      ),
                      SizedBox(height: scale.sm),
                      Text(
                        "YOU'LL EARN",
                        style: AppTheme.text(
                          size: 10,
                          weight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppTheme.imagePlaceholder,
                        ),
                      ),
                      SizedBox(height: scale.xs),
                      _EarnRow(
                        icon: Icons.stars_rounded,
                        iconColor: AppTheme.warningIcon,
                        label: '${controller.nextUnitPoints} Points',
                      ),
                      SizedBox(height: scale.xxs),
                      const _EarnRow(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: AppTheme.streakColor,
                        label: '1 streak',
                      ),
                      SizedBox(height: scale.xxs),
                      const _EarnRow(
                        icon: Icons.diamond_rounded,
                        iconColor: AppTheme.buttonColor,
                        label: '1 skill gem',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: scale.md),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: scale.buttonHeight - 2,
                  child: ElevatedButton(
                    onPressed: onStartNextActivity,
                    style: AppTheme.primaryButtonStyle(),
                    child: const Text("Let's go 🎉"),
                  ),
                ),
              ),
              SizedBox(width: scale.xs + 2),
              Expanded(
                child: SizedBox(
                  height: scale.buttonHeight - 2,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.invalidate(
                        learnerStateDataProvider(controller.learnerId),
                      );
                      context.go(AppRoutes.home);
                    },
                    style: AppTheme.secondaryButtonStyle(),
                    child: const Text('Maybe later'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTheme.text(size: 13, weight: FontWeight.w600),
        ),
      ],
    );
  }
}

class ClassWeeklyCapRevealBody extends StatelessWidget {
  const ClassWeeklyCapRevealBody({
    super.key,
    required this.unitIndex,
    required this.onHome,
  });

  final int unitIndex;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pageMuted,
      width: double.infinity,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = AppSpacingScale.fromWidth(constraints.maxWidth);

          final message = Center(
            child: Padding(
              padding: EdgeInsets.all(scale.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You did really well this week! 🎉',
                    textAlign: TextAlign.center,
                    style: AppTheme.text(size: 20, weight: FontWeight.w800),
                  ),
                  SizedBox(height: scale.xs),
                  Text(
                    "You've completed your activities for this week. See you next week!",
                    textAlign: TextAlign.center,
                    style: AppTheme.text(size: 14, color: AppTheme.subheadingColor),
                  ),
                  SizedBox(height: scale.xl),
                  SizedBox(
                    width: 220,
                    height: scale.buttonHeight,
                    child: ElevatedButton(
                      onPressed: onHome,
                      style: AppTheme.primaryButtonStyle(),
                      child: const Text('Back to home'),
                    ),
                  ),
                ],
              ),
            ),
          );

          if (!scale.showsSideRail) return message;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: message),
              SizedBox(
                width: scale.railWidth + scale.xl,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, scale.lg, scale.md, scale.lg),
                  child: ClassRevealRail(
                    unitIndex: unitIndex,
                    revealProgress: 1,
                    studentName: null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ClassRevealRail extends StatelessWidget {
  const ClassRevealRail({
    super.key,
    required this.unitIndex,
    required this.revealProgress,
    required this.studentName,
  });

  final int unitIndex;
  final double revealProgress;
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final progress = revealProgress.clamp(0.0, 1.0);
    final revealed = progress >= 1;

    return Container(
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.revealIconSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: AppTheme.streakColor,
                ),
              ),
              SizedBox(width: scale.xs),
              Expanded(
                child: Text(
                  "Today's picture",
                  style: AppTheme.text(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: scale.sm - 2),
          Text(
            revealed
                ? "Congratulations !!🎉 You have unlocked today's picture"
                : 'Complete the activity to reveal the secret character hiding behind the cloud! ☁️✨',
            style: AppTheme.text(
              size: 12,
              height: 1.45,
              color: AppTheme.subheadingColor,
            ),
          ),
          SizedBox(height: scale.sm),
          _RevealImage(
            unitIndex: unitIndex,
            revealProgress: progress,
            height: 150,
          ),
        ],
      ),
    );
  }
}

class _RevealImage extends StatefulWidget {
  const _RevealImage({
    required this.unitIndex,
    required this.revealProgress,
    required this.height,
  });

  final int unitIndex;
  final double revealProgress;
  final double height;

  @override
  State<_RevealImage> createState() => _RevealImageState();
}

class _RevealImageState extends State<_RevealImage> {
  late Future<String> _assetFuture;

  @override
  void initState() {
    super.initState();
    _assetFuture = RevealAssetResolver.resolve(widget.unitIndex);
  }

  @override
  void didUpdateWidget(covariant _RevealImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unitIndex != widget.unitIndex) {
      _assetFuture = RevealAssetResolver.resolve(widget.unitIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height;
    final revealProgress = widget.revealProgress;

    return FutureBuilder<String>(
      future: _assetFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: height,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.buttonColor),
            ),
          );
        }
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
                snapshot.data!,
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
                  opacity: (1 - revealProgress).clamp(0.0, 1.0),
                  duration: const Duration(milliseconds: 500),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 7 * (1 - revealProgress),
                      sigmaY: 7 * (1 - revealProgress),
                    ),
                    child: Container(color: Colors.white.withValues(alpha: 0)),
                  ),
                ),
              ),
              if (revealProgress < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CloudRevealPainter(
                        progress: revealProgress,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              if (revealProgress < 0.95)
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
      },
    );
  }
}

class _CloudRevealPainter extends CustomPainter {
  const _CloudRevealPainter({required this.progress, required this.color});

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
  bool shouldRepaint(covariant _CloudRevealPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
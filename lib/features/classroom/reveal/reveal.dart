import 'package:flutter/material.dart';
import 'package:tapapp/chat/reveal/reveal.dart';
import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/features/home/home.dart';

import 'package:flutter/services.dart' show rootBundle;

class RevealAssetResolver {
  RevealAssetResolver._();

  static const String _basePath = 'assets/images/reveal';
  static const String _fallbackAsset = 'assets/images/reveal/default.png';

  static Future<String> resolve(int unitIndex) async {
    final candidate = '$_basePath/unit_$unitIndex.png';
    if (await _assetExists(candidate)) return candidate;
    return _fallbackAsset;
  }

  static Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class RevealSidePanel extends StatelessWidget {
  const RevealSidePanel({super.key, required this.state});

  final RevealState state;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);

    return SizedBox(
      width: scale.railWidth + scale.xl,
      child: Padding(
        padding: EdgeInsets.only(left: scale.xl, top: scale.lg, bottom: scale.lg),
        child: RevealRailBody(state: state),
      ),
    );
  }
}

class ClassroomRevealSlot extends StatefulWidget {
  const ClassroomRevealSlot({
    super.key,
    required this.unitIndex,
    required this.revealProgress,
  });

  final int unitIndex;
  final double revealProgress;

  @override
  State<ClassroomRevealSlot> createState() => _ClassroomRevealSlotState();
}

class _ClassroomRevealSlotState extends State<ClassroomRevealSlot> {
  late Future<String> _assetFuture;

  @override
  void initState() {
    super.initState();
    _assetFuture = RevealAssetResolver.resolve(widget.unitIndex);
  }

  @override
  void didUpdateWidget(covariant ClassroomRevealSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unitIndex != widget.unitIndex) {
      _assetFuture = RevealAssetResolver.resolve(widget.unitIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _assetFuture,
      builder: (context, snapshot) {
        final assetPath = snapshot.data;
        if (assetPath == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.buttonColor),
          );
        }
        final state = RevealState(
          progress: widget.revealProgress,
          assetPath: assetPath,
        );
        return RevealRailBody(state: state);
      },
    );
  }
}

class RevealRailBody extends StatelessWidget {
  const RevealRailBody({super.key, required this.state});

  final RevealState state;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);

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
                  state.title,
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
            state.message,
            style: AppTheme.text(
              size: 12,
              height: 1.45,
              color: AppTheme.subheadingColor,
            ),
          ),
          SizedBox(height: scale.sm),
          RevealImage(state: state, height: 150),
        ],
      ),
    );
  }
}

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
                  child: ClassroomRevealSlot(
                    unitIndex: unitIndex,
                    revealProgress: 1,
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
        Text(label, style: AppTheme.text(size: 13, weight: FontWeight.w600)),
      ],
    );
  }
}
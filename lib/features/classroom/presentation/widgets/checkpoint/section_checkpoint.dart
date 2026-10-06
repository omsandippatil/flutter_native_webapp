import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';

enum ClassSectionCheckpointKind { video, submission, quiz, finalWin, generic }

class ClassSectionCheckpoint extends StatelessWidget {
  const ClassSectionCheckpoint({
    super.key,
    required this.kind,
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
    this.fillAvailableHeight = false,
  });

  final ClassSectionCheckpointKind kind;
  final String text;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool fillAvailableHeight;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);

    final content = Container(
      width: double.infinity,
      color: AppTheme.classroomBackground,
      padding: EdgeInsets.fromLTRB(
        scale.pageGutter,
        scale.section,
        scale.pageGutter,
        scale.section,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: scale.checkpointMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClassTapBuddySpeakingOrb(size: scale.orbSize),
              SizedBox(height: scale.lg),
              const _HearAgainPill(),
              SizedBox(height: scale.lg),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTheme.text(
                  size: scale.isCompact ? 18 : 20,
                  weight: FontWeight.w500,
                  height: 1.3,
                  color: AppTheme.textColor,
                ),
              ),
              SizedBox(height: scale.xl),
              SizedBox(
                width: scale.isCompact ? double.infinity : 292,
                height: scale.buttonHeight + 4,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: AppTheme.primaryButtonStyle(),
                  child: Text(
                    buttonLabel,
                    style: AppTheme.text(size: 14, weight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!fillAvailableHeight) return content;

    return SizedBox.expand(child: SingleChildScrollView(child: content));
  }
}

class _HearAgainPill extends StatelessWidget {
  const _HearAgainPill();

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    return Container(
      height: 34,
      padding: EdgeInsets.symmetric(horizontal: scale.md),
      decoration: BoxDecoration(
        color: AppTheme.chipLavender,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.volume_up_rounded,
            size: 15,
            color: AppTheme.buttonColor,
          ),
          SizedBox(width: scale.xs - 1),
          Text(
            'Hear again',
            style: AppTheme.text(
              size: 12,
              weight: FontWeight.w700,
              color: AppTheme.buttonColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ClassTapBuddySpeakingOrb extends StatefulWidget {
  const ClassTapBuddySpeakingOrb({super.key, this.size});

  final double? size;

  @override
  State<ClassTapBuddySpeakingOrb> createState() =>
      _ClassTapBuddySpeakingOrbState();
}

class _ClassTapBuddySpeakingOrbState extends State<ClassTapBuddySpeakingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? AppSpacing.of(context).orbSize;
    final middle = size * 0.85;
    final inner = size * 0.69;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final wave = Curves.easeInOut.transform(_controller.value);
          final reverseWave = Curves.easeInOut.transform(
            (_controller.value + 0.5) % 1,
          );
          final pulse = 1 + (0.025 * (wave < 0.5 ? wave * 2 : (1 - wave) * 2));

          return Stack(
            alignment: Alignment.center,
            children: [
              _SpeakingRipple(
                size: size * (0.88 + wave * 0.18),
                opacity: (0.34 * (1 - wave)).clamp(0.0, 0.34),
              ),
              _SpeakingRipple(
                size: size * (0.78 + reverseWave * 0.22),
                opacity: (0.22 * (1 - reverseWave)).clamp(0.0, 0.22),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: AppTheme.orbHalo.withValues(alpha: 0.52),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.scale(
                scale: 1 + ((pulse - 1) * 0.7),
                child: Container(
                  width: middle,
                  height: middle,
                  decoration: BoxDecoration(
                    color: AppTheme.orbMid.withValues(alpha: 0.42),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: inner,
                height: inner,
                decoration: const BoxDecoration(
                  color: AppTheme.orbCore,
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: size * 0.34,
                      height: size * 0.34,
                      decoration: const BoxDecoration(
                        color: AppTheme.orbFace,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/branding/tap_buddy_ai.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.smart_toy_rounded, size: 18),
                      ),
                    ),
                    SizedBox(height: size * 0.035),
                    Text(
                      'TAP Buddy',
                      style: AppTheme.text(
                        size: size * 0.066,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Speaking',
                      style: AppTheme.text(
                        size: size * 0.058,
                        weight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpeakingRipple extends StatelessWidget {
  const _SpeakingRipple({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.buttonColor.withValues(alpha: opacity),
          width: 5,
        ),
      ),
    );
  }
}
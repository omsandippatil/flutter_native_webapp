import 'package:flutter/material.dart';
import 'package:tapapp/core/theme/theme.dart';

class ClassLoadingSkeleton extends StatelessWidget {
  const ClassLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = AppSpacingScale.fromWidth(constraints.maxWidth);
        return Container(
          color: AppTheme.appBackground,
          child: Column(
            children: [
              _SkeletonHeader(scale: scale),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: scale.contentMaxWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: scale.pageGutter,
                        vertical: scale.xl,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: scale.chatMaxWidth,
                                ),
                                child: _ChatSkeletonCard(scale: scale),
                              ),
                            ),
                          ),
                          if (scale.showsSideRail)
                            SizedBox(
                              width: scale.railWidth + scale.xl,
                              child: Padding(
                                padding: EdgeInsets.only(left: scale.xl),
                                child: _RevealRailSkeleton(scale: scale),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _InputSkeleton(scale: scale),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader({required this.scale});

  final AppSpacingScale scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72 * scale.factor,
      padding: EdgeInsets.symmetric(horizontal: scale.pageGutter),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          _CircleSkeleton(size: 40 * scale.factor),
          SizedBox(width: scale.md),
          Expanded(child: _BarSkeleton(height: 22 * scale.factor)),
          SizedBox(width: scale.xl),
          _BarSkeleton(width: 64 * scale.factor, height: 26 * scale.factor),
          SizedBox(width: scale.xs),
          _BarSkeleton(width: 120 * scale.factor, height: 26 * scale.factor),
          SizedBox(width: scale.xs),
          _BarSkeleton(width: 88 * scale.factor, height: 26 * scale.factor),
        ],
      ),
    );
  }
}

class _ChatSkeletonCard extends StatelessWidget {
  const _ChatSkeletonCard({required this.scale});

  final AppSpacingScale scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BarSkeleton(width: 280, height: 28),
          SizedBox(height: scale.sm),
          _BarSkeleton(width: double.infinity, height: 160),
          SizedBox(height: scale.md),
          _BarSkeleton(width: double.infinity, height: 30),
          SizedBox(height: scale.sm),
          _BarSkeleton(width: double.infinity, height: 30),
          SizedBox(height: scale.sm),
          _BarSkeleton(width: double.infinity, height: 30),
          SizedBox(height: scale.lg),
          Align(
            alignment: Alignment.centerRight,
            child: _BarSkeleton(
              width: 260,
              height: 30,
              color: AppTheme.successBubble,
            ),
          ),
          SizedBox(height: scale.sm),
          _BarSkeleton(width: double.infinity, height: 30),
        ],
      ),
    );
  }
}

class _RevealRailSkeleton extends StatelessWidget {
  const _RevealRailSkeleton({required this.scale});

  final AppSpacingScale scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BarSkeleton(width: 120, height: 22),
          SizedBox(height: scale.sm),
          const _BarSkeleton(width: double.infinity, height: 82),
          SizedBox(height: scale.md),
          const _BarSkeleton(width: double.infinity, height: 150),
        ],
      ),
    );
  }
}

class _InputSkeleton extends StatelessWidget {
  const _InputSkeleton({required this.scale});

  final AppSpacingScale scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scale.pageGutter,
        vertical: scale.sm,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: scale.chatMaxWidth),
          child: Row(
            children: [
              const Expanded(child: _BarSkeleton(height: 40)),
              SizedBox(width: scale.xs),
              _CircleSkeleton(
                size: 40 * scale.factor,
                color: AppTheme.buttonColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarSkeleton extends StatelessWidget {
  const _BarSkeleton({
    this.width,
    required this.height,
    this.color = AppTheme.fieldBackground,
  });

  final double? width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderColor),
      ),
    );
  }
}

class _CircleSkeleton extends StatelessWidget {
  const _CircleSkeleton({
    required this.size,
    this.color = AppTheme.fieldBackground,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

import 'package:flutter/widgets.dart';

enum AppBreakpoint { compact, medium, expanded }

class AppSpacingScale {
  const AppSpacingScale._({required this.breakpoint, required this.factor});

  final AppBreakpoint breakpoint;
  final double factor;

  bool get isCompact => breakpoint == AppBreakpoint.compact;
  bool get showsSideRail => breakpoint != AppBreakpoint.compact;

  double get xxs => 4 * factor;
  double get xs => 8 * factor;
  double get sm => 12 * factor;
  double get md => 16 * factor;
  double get lg => 20 * factor;
  double get xl => 24 * factor;
  double get xxl => 32 * factor;
  double get section => 40 * factor;

  double get pageGutter => isCompact ? md : xxl;
  double get chatMaxWidth => isCompact ? 760 : 720;
  double get contentMaxWidth => 1120;
  double get railWidth => 260 * factor;
  double get buttonHeight => 50 * factor;
  double get avatarSize => 30 * factor;
  double get orbSize => 136 * factor;
  double get checkpointMaxWidth => 740;
  double get userBubbleMaxWidth => 560;
  double get previewHeight => 190 * factor;

  static AppSpacingScale fromWidth(double width) {
    if (width >= 1120) {
      return const AppSpacingScale._(
        breakpoint: AppBreakpoint.expanded,
        factor: 1.15,
      );
    }
    if (width >= 640) {
      return const AppSpacingScale._(
        breakpoint: AppBreakpoint.medium,
        factor: 1.08,
      );
    }
    return const AppSpacingScale._(
      breakpoint: AppBreakpoint.compact,
      factor: 1,
    );
  }
}

class AppSpacing {
  AppSpacing._();

  static AppSpacingScale of(BuildContext context) =>
      AppSpacingScale.fromWidth(MediaQuery.sizeOf(context).width);
}
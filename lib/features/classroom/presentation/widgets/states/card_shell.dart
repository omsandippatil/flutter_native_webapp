import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';

class ClassCardShell extends StatelessWidget {
  const ClassCardShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: child,
    );
  }
}
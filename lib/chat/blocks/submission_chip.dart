import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';

class SubmissionChip extends StatelessWidget {
  const SubmissionChip({
    super.key,
    required this.label,
    this.foregroundColor = AppTheme.textColor,
  });

  final String label;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scale.sm - 2,
        vertical: scale.xs - 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Text(
        label,
        style: AppTheme.text(
          size: 11,
          weight: FontWeight.w800,
          color: foregroundColor,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';

class SubmissionReviewBlock extends StatelessWidget {
  const SubmissionReviewBlock({super.key, required this.item});

  final SubmissionReviewItem item;

  @override
  Widget build(BuildContext context) {
    final failed = !item.passed;
    final feedback = item.feedback;
    final score = item.score;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: failed ? AppTheme.dangerSurface : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: failed ? AppTheme.dangerBorder : AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (failed) ...[
                const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.dangerText),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  item.text ?? '',
                  style: AppTheme.text(
                    size: 17,
                    weight: FontWeight.w700,
                    height: 1.3,
                    color: failed ? AppTheme.dangerText : AppTheme.textColor,
                  ),
                ),
              ),
              if (score != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: failed ? AppTheme.dangerChip : AppTheme.successSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'Score: $score',
                    style: AppTheme.text(
                      size: 13,
                      weight: FontWeight.w800,
                      color: failed ? AppTheme.dangerText : AppTheme.successText,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              feedback,
              style: AppTheme.text(
                size: 15,
                height: 1.5,
                color: failed ? AppTheme.dangerText : AppTheme.subheadingColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
} 
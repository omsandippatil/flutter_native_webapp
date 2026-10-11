import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/blocks/submission_chip.dart';
import 'package:tapapp/chat/model/model.dart';

Future<void> showSubmissionHelpDialog(
  BuildContext context,
  SubmissionItem item,
  String kindLabel,
) async {
  final scale = AppSpacing.of(context);
  final guidedText = item.guidedText;
  final prompt = guidedText?.isNotEmpty == true
      ? guidedText!
      : item.unguidedText;
  final validCriteria = item.validCriteria;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: scale.md,
        vertical: scale.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(scale.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: SubmissionChip(label: kindLabel)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: scale.sm),
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: 34,
                  color: AppTheme.imagePlaceholder,
                ),
              ),
              SizedBox(height: scale.md),
              Text(prompt, style: AppTheme.text(size: 14, height: 1.45)),
              if (validCriteria?.isNotEmpty == true) ...[
                SizedBox(height: scale.xs),
                Text(
                  validCriteria!,
                  style: AppTheme.text(
                    size: 12,
                    height: 1.4,
                    color: AppTheme.subheadingColor,
                  ),
                ),
              ],
              SizedBox(height: scale.lg),
              SizedBox(
                width: double.infinity,
                height: scale.buttonHeight - 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: AppTheme.primaryButtonStyle(),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
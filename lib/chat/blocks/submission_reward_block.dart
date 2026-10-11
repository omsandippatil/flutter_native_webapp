import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/action/action.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

class SubmissionRewardBlock extends StatelessWidget {
  const SubmissionRewardBlock({super.key, required this.item, required this.ctx});

  final SubmissionRewardItem item;
  final ChatRenderContext ctx;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: AppTheme.classroomMessageSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/classroom/Skill_Passport_1.png',
              height: 235,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 235,
                child: Icon(Icons.image_rounded, size: 40, color: AppTheme.imagePlaceholder),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Congratulations ${item.studentName}!',
              textAlign: TextAlign.center,
              style: AppTheme.text(size: 20, weight: FontWeight.w900, color: AppTheme.textColor),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.rewardGold,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                '+${item.points} pts',
                style: AppTheme.text(size: 14, weight: FontWeight.w800, color: AppTheme.textColor),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: ctx.isAwaitingInput
                    ? () => ctx.onAction(ChatAction.continueFlow, data: {'stepId': item.stepId})
                    : null,
                style: AppTheme.primaryButtonStyle(),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 

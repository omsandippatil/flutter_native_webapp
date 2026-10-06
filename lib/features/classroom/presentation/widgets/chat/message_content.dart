import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';
import 'package:tapapp/features/classroom/application/classroom_session_controller.dart';
import 'package:tapapp/features/classroom/models/classroom_message.dart';
import 'package:tapapp/features/classroom/presentation/widgets/checkpoint/section_checkpoint.dart';
import 'package:tapapp/features/classroom/presentation/widgets/quiz/quiz_question_card.dart';
import 'package:tapapp/features/classroom/presentation/widgets/states/card_shell.dart';
import 'package:tapapp/features/classroom/presentation/widgets/submission/submission_card.dart';
import 'package:tapapp/features/classroom/presentation/widgets/video/video_card.dart';

class ClassMessageContent extends StatelessWidget {
  const ClassMessageContent({
    super.key,
    required this.message,
    required this.controller,
    required this.isUser,
  });

  final ClassChatMessage message;
  final ClassChatController controller;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    switch (message.contentType) {
      case ClassChatContentType.text:
      case ClassChatContentType.unitTransition:
        return ClassTextBubble(text: message.text ?? '', isUser: isUser);
      case ClassChatContentType.checkpoint:
        return ClassCheckpointCard(message: message, controller: controller);
      case ClassChatContentType.video:
        return ClassVideoCard(
          key: ValueKey('video_${message.id}'),
          message: message,
          controller: controller,
        );
      case ClassChatContentType.submission:
        return ClassSubmissionCard(
          key: ValueKey('submission_${message.id}'),
          message: message,
          controller: controller,
        );
      case ClassChatContentType.submissionAnswerEcho:
        return ClassTextBubble(text: message.text ?? '', isUser: true);
      case ClassChatContentType.submissionReviewing:
        return const ClassTextBubble(
          text: 'Reviewing your submission...',
          isUser: false,
          isMuted: true,
        );
      case ClassChatContentType.submissionReview:
        return ClassSubmissionReviewCard(message: message);
      case ClassChatContentType.submissionReward:
        return ClassSubmissionRewardCard(
          message: message,
          controller: controller,
        );
      case ClassChatContentType.quizQuestion:
        return isUser
            ? ClassTextBubble(text: message.text ?? '', isUser: true)
            : ClassQuizQuestionCard(
                key: ValueKey('quiz_${message.id}'),
                message: message,
                controller: controller,
              );
      case ClassChatContentType.quizAnswerEcho:
        return ClassTextBubble(text: message.text ?? '', isUser: true);
      case ClassChatContentType.quizFeedback:
        return ClassQuizFeedbackCard(message: message);
      case ClassChatContentType.quizSummary:
        return ClassQuizSummaryCard(message: message);
      case ClassChatContentType.sessionEnd:
      case ClassChatContentType.weeklyCapReached:
      case ClassChatContentType.loading:
        return const SizedBox.shrink();
      case ClassChatContentType.errorRetry:
        return ClassErrorRetryCard(message: message, controller: controller);
    }
  }
}

class ClassCheckpointCard extends StatelessWidget {
  const ClassCheckpointCard({
    super.key,
    required this.message,
    required this.controller,
    this.fillAvailableHeight = false,
  });

  final ClassChatMessage message;
  final ClassChatController controller;
  final bool fillAvailableHeight;

  static const Set<String> _sectionActions = {
    'video',
    'submission',
    'submission_retry',
    'quiz',
  };

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final image = message.data['image'] as String?;
    final buttonLabel = message.data['buttonLabel'] as String? ?? 'Continue';
    final action = message.data['action'] as String? ?? '';

    if (_sectionActions.contains(action)) {
      return ClassSectionCheckpoint(
        kind: switch (action) {
          'video' => ClassSectionCheckpointKind.video,
          'quiz' => ClassSectionCheckpointKind.quiz,
          _ => ClassSectionCheckpointKind.submission,
        },
        text: message.text ?? '',
        buttonLabel: buttonLabel,
        onPressed: () => controller.continueCheckpoint(action),
        fillAvailableHeight: fillAvailableHeight,
      );
    }

    if ((action == 'quiz_begin_art' || action == 'quiz_complete_art') &&
        image != null) {
      return _artPanel(scale, image);
    }

    if (action == 'video_reward' && image != null) {
      return _rewardPanel(scale, image, buttonLabel, action);
    }

    if (action == 'finish' && image != null) {
      return _finalPanel(scale, image, buttonLabel, action);
    }

    return _promptPanel(scale, image, buttonLabel, action);
  }

  Widget _artPanel(AppSpacingScale scale, String image) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: EdgeInsets.all(scale.xs),
        decoration: BoxDecoration(
          color: AppTheme.classroomMessageSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Image.asset(image, height: 260, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _rewardPanel(
    AppSpacingScale scale,
    String image,
    String buttonLabel,
    String action,
  ) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(scale.sm),
              decoration: BoxDecoration(
                color: AppTheme.classroomMessageSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(image, fit: BoxFit.cover),
                ),
              ),
            ),
            SizedBox(height: scale.md),
            Container(
              padding: EdgeInsets.fromLTRB(
                scale.md,
                scale.sm,
                scale.md,
                scale.md,
              ),
              decoration: BoxDecoration(
                color: AppTheme.classroomMessageSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      message.text ?? '',
                      style: AppTheme.text(size: 18, height: 1.35),
                    ),
                  ),
                  SizedBox(width: scale.xs),
                  const Icon(
                    Icons.volume_up_rounded,
                    size: 22,
                    color: AppTheme.buttonColor,
                  ),
                ],
              ),
            ),
            SizedBox(height: scale.lg),
            SizedBox(
              height: scale.buttonHeight,
              child: ElevatedButton(
                onPressed: () => controller.continueCheckpoint(action),
                style: AppTheme.primaryButtonStyle(radius: AppTheme.radiusLg),
                child: Text(
                  buttonLabel,
                  style: AppTheme.text(
                    size: 17,
                    weight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finalPanel(
    AppSpacingScale scale,
    String image,
    String buttonLabel,
    String action,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: EdgeInsets.all(scale.sm),
        decoration: BoxDecoration(
          color: AppTheme.classroomMessageSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Image.asset(image, height: 210, fit: BoxFit.contain),
            ),
            SizedBox(height: scale.sm),
            Text(
              message.text ?? '',
              textAlign: TextAlign.center,
              style: AppTheme.text(
                size: 13,
                height: 1.45,
                weight: FontWeight.w600,
              ),
            ),
            SizedBox(height: scale.sm),
            SizedBox(
              width: double.infinity,
              height: scale.buttonHeight,
              child: ElevatedButton(
                onPressed: () => controller.continueCheckpoint(action),
                style: AppTheme.primaryButtonStyle(),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promptPanel(
    AppSpacingScale scale,
    String? image,
    String buttonLabel,
    String action,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        scale.lg,
        scale.xl,
        scale.lg,
        scale.xl,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClassTapBuddySpeakingOrb(size: scale.orbSize),
          SizedBox(height: scale.sm),
          Container(
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
                SizedBox(width: scale.xxs + 2),
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
          ),
          if (image != null) ...[
            SizedBox(height: scale.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230, maxWidth: 360),
              child: Image.asset(
                image,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
          SizedBox(height: scale.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              message.text ?? '',
              textAlign: TextAlign.center,
              style: AppTheme.text(
                size: 17,
                height: 1.4,
                weight: FontWeight.w500,
                color: AppTheme.stemText,
              ),
            ),
          ),
          SizedBox(height: scale.xl),
          SizedBox(
            width: 280,
            height: scale.buttonHeight,
            child: ElevatedButton(
              onPressed: action.isEmpty
                  ? null
                  : () => controller.continueCheckpoint(action),
              style: AppTheme.primaryButtonStyle(
                radius: AppTheme.radiusSm + 2,
              ),
              child: Text(
                buttonLabel,
                style: AppTheme.text(size: 14, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassTextBubble extends StatelessWidget {
  const ClassTextBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isMuted = false,
  });

  final String text;
  final bool isUser;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);

    if (isUser) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: scale.md, vertical: scale.sm),
        decoration: const BoxDecoration(
          color: AppTheme.userBubble,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusMd + 2),
            topRight: Radius.circular(AppTheme.radiusSm - 6),
            bottomLeft: Radius.circular(AppTheme.radiusMd + 2),
            bottomRight: Radius.circular(AppTheme.radiusMd + 2),
          ),
        ),
        child: Text(
          text,
          style: AppTheme.text(size: 15, height: 1.45),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: scale.md, vertical: scale.sm),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusSm - 6),
          topRight: Radius.circular(AppTheme.radiusMd + 2),
          bottomLeft: Radius.circular(AppTheme.radiusMd + 2),
          bottomRight: Radius.circular(AppTheme.radiusMd + 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTheme.text(
                size: 14,
                height: 1.5,
                fontStyle: isMuted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          SizedBox(width: scale.xs),
          const Icon(
            Icons.volume_up_rounded,
            size: 18,
            color: AppTheme.imagePlaceholder,
          ),
        ],
      ),
    );
  }
}

class ClassErrorRetryCard extends StatelessWidget {
  const ClassErrorRetryCard({
    super.key,
    required this.message,
    required this.controller,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    return ClassCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text ?? 'Something went wrong.',
            style: AppTheme.text(size: 14, weight: FontWeight.w600, height: 1.4),
          ),
          SizedBox(height: scale.sm),
          SizedBox(
            width: double.infinity,
            height: scale.buttonHeight - 6,
            child: ElevatedButton(
              onPressed: controller.retryAfterError,
              style: AppTheme.primaryButtonStyle(),
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
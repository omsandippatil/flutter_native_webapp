import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';
import 'package:tapapp/features/classroom/application/classroom_session_controller.dart';
import 'package:tapapp/features/classroom/models/classroom_message.dart';
import 'package:tapapp/features/classroom/presentation/widgets/states/card_shell.dart';

class ClassQuizQuestionCard extends StatefulWidget {
  const ClassQuizQuestionCard({
    super.key,
    required this.message,
    required this.controller,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  State<ClassQuizQuestionCard> createState() => _ClassQuizQuestionCardState();
}

class _ClassQuizQuestionCardState extends State<ClassQuizQuestionCard> {
  String? _selectedKey;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final questionIndex = widget.message.data['questionIndex'] as int? ?? 0;
    final totalQuestions = widget.message.data['totalQuestions'] as int? ?? 0;
    final question = widget.message.data['question'] as String? ?? '';
    final options =
        (widget.message.data['options'] as Map?)?.cast<String, String>() ??
        const {};
    final answerKey = widget.message.data['answerKey'] as String?;
    final optionEntries = options.entries.toList();
    final canAnswer = widget.controller.isAwaitingInput && !_confirmed;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${questionIndex + 1}. $question',
            style: AppTheme.text(size: 16, weight: FontWeight.w700, height: 1.35),
          ),
          SizedBox(height: scale.xxs),
          Text(
            'Question ${questionIndex + 1} of $totalQuestions',
            style: AppTheme.text(
              size: 11,
              weight: FontWeight.w600,
              color: AppTheme.imagePlaceholder,
            ),
          ),
          SizedBox(height: scale.md),
          ...optionEntries.map((option) {
            final selected = _selectedKey == option.key;
            final isCorrectOption =
                answerKey != null && option.key == answerKey;

            var fillColor = AppTheme.cardBackground;
            var borderColor = AppTheme.borderColor;
            var textColor = AppTheme.textColor;

            if (_confirmed) {
              if (isCorrectOption) {
                fillColor = AppTheme.buttonColor;
                borderColor = AppTheme.buttonColor;
                textColor = Colors.white;
              } else if (selected) {
                fillColor = AppTheme.wrongAnswerSurface;
                borderColor = AppTheme.wrongAnswerBorder;
                textColor = AppTheme.dangerText;
              }
            } else if (selected) {
              borderColor = AppTheme.buttonColor;
            }

            return Padding(
              padding: EdgeInsets.only(bottom: scale.xs),
              child: InkWell(
                onTap: canAnswer
                    ? () => setState(() => _selectedKey = option.key)
                    : null,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: scale.sm,
                    horizontal: scale.md,
                  ),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: borderColor,
                      width: selected || (_confirmed && isCorrectOption)
                          ? 1.8
                          : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.value,
                          style: AppTheme.text(
                            size: 14,
                            weight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (_confirmed && isCorrectOption)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      if (_confirmed && selected && !isCorrectOption)
                        const Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: AppTheme.dangerText,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          SizedBox(height: scale.xs),
          SizedBox(
            width: double.infinity,
            height: scale.buttonHeight - 2,
            child: ElevatedButton(
              onPressed: (canAnswer && _selectedKey != null)
                  ? () {
                      setState(() => _confirmed = true);
                      widget.controller.submitQuizAnswer(_selectedKey!);
                    }
                  : null,
              style: AppTheme.primaryButtonStyle(
                disabledColor: AppTheme.mutedLavender,
              ),
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassQuizFeedbackCard extends StatelessWidget {
  const ClassQuizFeedbackCard({required this.message, super.key});

  final ClassChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final isCorrect = message.data['isCorrect'] as bool? ?? false;
    final explanation = message.data['explanation'] as String?;
    final correctOptionText = message.data['correctOptionText'] as String?;
    final earnedPoints = message.data['earnedPoints'] as int?;

    return Container(
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: isCorrect ? AppTheme.successSurface : AppTheme.warningSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
                size: 18,
                color: isCorrect ? AppTheme.streakColor : AppTheme.warningIcon,
              ),
              SizedBox(width: scale.xs - 2),
              Text(
                isCorrect
                    ? (earnedPoints != null
                          ? 'Correct! +$earnedPoints points'
                          : 'Correct!')
                    : 'Not quite',
                style: AppTheme.text(size: 15, weight: FontWeight.w800),
              ),
            ],
          ),
          if (!isCorrect && correctOptionText != null) ...[
            SizedBox(height: scale.xs),
            Text(
              'Correct answer: $correctOptionText',
              style: AppTheme.text(
                size: 13,
                weight: FontWeight.w600,
                color: AppTheme.answerText,
              ),
            ),
          ],
          if (explanation != null && explanation.isNotEmpty) ...[
            SizedBox(height: scale.xxs + 2),
            Text(
              explanation,
              style: AppTheme.text(
                size: 13,
                height: 1.45,
                color: AppTheme.answerText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ClassQuizSummaryCard extends StatelessWidget {
  const ClassQuizSummaryCard({required this.message, super.key});

  final ClassChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final correct = message.data['correct'] as int? ?? 0;
    final total = message.data['total'] as int? ?? 0;

    return ClassCardShell(
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppTheme.rewardGold,
            size: 28,
          ),
          SizedBox(width: scale.sm),
          Expanded(
            child: Text(
              '${message.text ?? 'Quiz done!'}\nYou got $correct out of $total correct.',
              style: AppTheme.text(size: 14, height: 1.45, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
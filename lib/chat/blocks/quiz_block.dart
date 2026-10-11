import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

class QuizBlock extends StatefulWidget {
  const QuizBlock({super.key, required this.item, required this.ctx});

  final QuizItem item;
  final ChatRenderContext ctx;

  @override
  State<QuizBlock> createState() => _QuizBlockState();
}

class _QuizBlockState extends State<QuizBlock> {
  String? _selectedKey;

  void _select(String key) {
    if (!widget.ctx.isAwaitingInput || _selectedKey != null) return;
    setState(() => _selectedKey = key);
    final isCorrect = key == widget.item.answerKey;
    widget.ctx.onOptionSelected(widget.item.stepId, isCorrect ? 'correct' : 'wrong');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final enabled = widget.ctx.isAwaitingInput && _selectedKey == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${item.questionIndex + 1}/${item.totalQuestions}',
            style: AppTheme.text(size: 12, color: AppTheme.subheadingColor),
          ),
          const SizedBox(height: 8),
          Text(item.question, style: AppTheme.text(size: 16, weight: FontWeight.w800, height: 1.35)),
          const SizedBox(height: 16),
          for (final option in item.options) ...[
            _AnswerButton(
              label: option.label,
              selected: _selectedKey == option.key,
              isCorrect: option.key == item.answerKey,
              revealed: _selectedKey != null,
              enabled: enabled,
              onTap: () => _select(option.key),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showCorrect = revealed && isCorrect;
    final showWrong = revealed && selected && !isCorrect;

    final bg = showCorrect
        ? AppTheme.successSurface
        : showWrong
            ? AppTheme.wrongAnswerSurface
            : AppTheme.cardBackground;
    final border = showCorrect
        ? AppTheme.streakColor
        : showWrong
            ? AppTheme.wrongAnswerBorder
            : AppTheme.borderColor;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: border),
        ),
        child: Text(label, style: AppTheme.text(size: 14, weight: FontWeight.w600, color: AppTheme.answerText)),
      ),
    );
  }
} 
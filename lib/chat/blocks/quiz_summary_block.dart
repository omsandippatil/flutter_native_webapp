import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';

class QuizSummaryBlock extends StatelessWidget {
  const QuizSummaryBlock({super.key, required this.item});

  final QuizSummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Text(
            '${item.correct}/${item.total}',
            style: AppTheme.text(size: 22, weight: FontWeight.w900, color: AppTheme.buttonColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.text ?? 'Correct answers', style: AppTheme.text(size: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
} 
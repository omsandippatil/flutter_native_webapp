import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/action/action.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

class NextActivityBlock extends StatelessWidget {
  const NextActivityBlock({super.key, required this.item, required this.ctx});

  final NextActivityItem item;
  final ChatRenderContext ctx;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.courseDisplay, style: AppTheme.text(size: 12, color: AppTheme.imagePlaceholder)),
          const SizedBox(height: 4),
          Text(
            item.hasNextUnit ? item.unitName : 'All caught up for now',
            style: AppTheme.text(size: 17, weight: FontWeight.w800),
          ),
          if (item.hasNextUnit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.stars_rounded, size: 15, color: AppTheme.pointColor),
                const SizedBox(width: 6),
                Text('${item.points} Points', style: AppTheme.text(size: 13, weight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (item.hasNextUnit)
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => ctx.onAction(ChatAction.watchAnother),
                      style: AppTheme.primaryButtonStyle(),
                      child: const Text('Continue'),
                    ),
                  ),
                ),
              if (item.hasNextUnit) const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => ctx.onAction(ChatAction.openHome),
                    child: const Text('Home'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 
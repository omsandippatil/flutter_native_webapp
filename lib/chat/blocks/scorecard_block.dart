import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';

class ScorecardBlock extends StatelessWidget {
  const ScorecardBlock({super.key, required this.item});

  final ScorecardItem item;

  @override
  Widget build(BuildContext context) {
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
          for (final row in item.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (row.icon != null) ...[
                    Icon(row.icon, size: 16, color: AppTheme.buttonColor),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(row.label, style: AppTheme.text(size: 13, color: AppTheme.subheadingColor)),
                  ),
                  Text(row.value, style: AppTheme.text(size: 14, weight: FontWeight.w800)),
                ],
              ),
            ),
          if (item.total != null) ...[
            const SizedBox(height: 8),
            const Divider(color: AppTheme.dividerColor),
            const SizedBox(height: 8),
            Text(item.total!, style: AppTheme.text(size: 15, weight: FontWeight.w900)),
          ],
        ],
      ),
    );
  }
} 
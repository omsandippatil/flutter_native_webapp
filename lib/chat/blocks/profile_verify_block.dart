import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

class ProfileVerifyBlock extends StatelessWidget {
  const ProfileVerifyBlock({super.key, required this.item, required this.ctx});

  final ProfileVerifyItem item;
  final ChatRenderContext ctx;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.classroomMessageSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in item.fields.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(entry.key, style: AppTheme.text(size: 13, color: AppTheme.subheadingColor)),
                  ),
                  Text(entry.value, style: AppTheme.text(size: 13, weight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 

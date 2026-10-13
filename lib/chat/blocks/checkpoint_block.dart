import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

Widget checkpointBlockFor(CheckpointItem item, ChatRenderContext ctx) {
  return Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.image != null) ...[
            Image.asset(
              item.image!,
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
          ],
          if (item.text?.isNotEmpty == true) ...[
            Text(
              item.text!,
              textAlign: TextAlign.center,
              style: AppTheme.text(size: 16, weight: FontWeight.w700, height: 1.4),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: ctx.isAwaitingInput ? () => ctx.checkpoint(item) : null,
              style: AppTheme.primaryButtonStyle(),
              child: Text(item.buttonLabel),
            ),
          ),
        ],
      ),
    ),
  );
} 

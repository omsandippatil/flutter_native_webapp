import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';

class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.item, required this.ctx});

  final ErrorItem item;
  final ChatRenderContext ctx;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.message, style: AppTheme.text(size: 14, color: AppTheme.dangerText)),
          if (item.retryAction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: () => ctx.onRetry(item.retryAction),
                style: AppTheme.primaryButtonStyle(),
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 

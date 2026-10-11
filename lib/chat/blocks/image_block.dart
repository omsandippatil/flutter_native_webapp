import 'package:flutter/material.dart';

import 'package:tapapp/core/theme/theme.dart';

class ImageBlock extends StatelessWidget {
  const ImageBlock({super.key, required this.src, this.caption, this.alt});

  final String src;
  final String? caption;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final isNetwork = src.startsWith('http');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: isNetwork
              ? Image.network(src, fit: BoxFit.cover, errorBuilder: _error)
              : Image.asset(src, fit: BoxFit.cover, errorBuilder: _error),
        ),
        if (caption?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(caption!, style: AppTheme.text(size: 13, height: 1.4)),
        ],
      ],
    );
  }

  Widget _error(BuildContext context, Object error, StackTrace? stack) => Container(
    height: 160,
    color: AppTheme.classroomMessageSurface,
    child: const Icon(Icons.image_rounded, size: 34, color: AppTheme.imagePlaceholder),
  );
}  
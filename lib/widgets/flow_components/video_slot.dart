import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

class ActivityVideoSlot extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onComplete;

  const ActivityVideoSlot({
    super.key,
    required this.video,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final description = video['description'] as String? ?? 'activity video';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InstructionPill(text: 'Watch the video 👇'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCDDE7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEDF1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: InkWell(
                      onTap: onComplete,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: AppTheme.buttonColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Watch: $description',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1C1C21),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstructionPill extends StatelessWidget {
  final String text;

  const _InstructionPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1C1C21),
            ),
          ),
          const SizedBox(width: 28),
          const Icon(
            Icons.volume_up_rounded,
            color: AppTheme.buttonColor,
            size: 16,
          ),
        ],
      ),
    );
  }
}

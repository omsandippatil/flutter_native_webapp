import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

class ActivityQuizCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final int questionNumber;
  final ValueChanged<String> onAnswer;

  const ActivityQuizCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.onAnswer,
  });

  @override
  State<ActivityQuizCard> createState() => _ActivityQuizCardState();
}

class _ActivityQuizCardState extends State<ActivityQuizCard> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final options = widget.question['options'] as List<dynamic>? ?? const [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCDDE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 138,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                size: 30,
                color: Color(0xFFB9BBC8),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Q${widget.questionNumber}. ${widget.question['prompt'] as String? ?? 'Quiz question'}',
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C21),
            ),
          ),
          const SizedBox(height: 16),
          for (final raw in options)
            _OptionTile(
              option: raw as Map<String, dynamic>,
              selected: _selected == raw['option_id'],
              onTap: () =>
                  setState(() => _selected = raw['option_id'] as String?),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => widget.onAnswer(_selected!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E4FA),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final Map<String, dynamic> option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE5E4FA) : const Color(0xFFF7F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.buttonColor : const Color(0xFFE1E2EA),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AppTheme.buttonColor
                    : const Color(0xFF8E8E9F),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option['text'] as String? ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C21),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

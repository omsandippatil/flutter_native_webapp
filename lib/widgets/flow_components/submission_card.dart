import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

enum SubmissionMode { screenshot, emoji, text, voice, video }

class ActivitySubmissionCard extends StatefulWidget {
  final Map<String, dynamic> submission;
  final ValueChanged<String> onSubmit;
  final VoidCallback onHelp;

  const ActivitySubmissionCard({
    super.key,
    required this.submission,
    required this.onSubmit,
    required this.onHelp,
  });

  @override
  State<ActivitySubmissionCard> createState() => _ActivitySubmissionCardState();
}

class _ActivitySubmissionCardState extends State<ActivitySubmissionCard> {
  SubmissionMode _mode = SubmissionMode.emoji;
  String _selected = '😺';

  @override
  void initState() {
    super.initState();
    _mode = _allowedModes.first;
    _selected = _defaultSelection(_mode);
  }

  @override
  void didUpdateWidget(covariant ActivitySubmissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.submission['type'] != widget.submission['type']) {
      _mode = _allowedModes.first;
      _selected = _defaultSelection(_mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompt =
        widget.submission['prompt'] as String? ??
        'Share a clear screenshot or video of your activity.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDF3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: "TODAY'S ACTIVITY 🛶🛶", selected: false),
              for (final mode in _allowedModes)
                _ModeChip(
                  label: _modeLabel(mode),
                  selected: _mode == mode,
                  onTap: () => _setMode(mode),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E2EA), width: 6),
            ),
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                size: 32,
                color: Color(0xFFB9BBC8),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            prompt,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C21),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _helperLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF777887),
            ),
          ),
          const SizedBox(height: 8),
          _modeBody(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => widget.onSubmit(_selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Submit'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: widget.onHelp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E4FA),
                      foregroundColor: AppTheme.buttonColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Submission Help'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _helperLabel {
    return switch (_mode) {
      SubmissionMode.emoji => 'Friends sent 👀',
      SubmissionMode.text => 'Friends said 👀',
      SubmissionMode.voice => 'Hear what friends sent 👀',
      _ => 'See what friends made 👀',
    };
  }

  List<SubmissionMode> get _allowedModes {
    final type = (widget.submission['type'] as String? ?? '').toLowerCase();
    if (type.contains('emoji')) return const [SubmissionMode.emoji];
    if (type.contains('text') || type.contains('word')) {
      return const [SubmissionMode.text];
    }
    if (type.contains('voice') || type.contains('audio')) {
      return const [SubmissionMode.voice];
    }
    if (type.contains('video')) return const [SubmissionMode.video];
    if (type.contains('photo') ||
        type.contains('image') ||
        type.contains('screenshot')) {
      return const [SubmissionMode.screenshot];
    }
    return const [
      SubmissionMode.screenshot,
      SubmissionMode.emoji,
      SubmissionMode.text,
      SubmissionMode.voice,
      SubmissionMode.video,
    ];
  }

  String _modeLabel(SubmissionMode mode) {
    return switch (mode) {
      SubmissionMode.screenshot => '🖼 SCREENSHOT',
      SubmissionMode.emoji => '👉 EMOJI',
      SubmissionMode.text => '🔤 TEXT',
      SubmissionMode.voice => '🎤 VOICE',
      SubmissionMode.video => '🎥 VIDEO',
    };
  }

  Widget _modeBody() {
    return switch (_mode) {
      SubmissionMode.text => _choiceList(['Fun!', 'Robot', 'Wow!']),
      SubmissionMode.voice => Column(
        children: [
          _AudioChoice(
            selected: _selected == 'voice-1',
            onTap: () => setState(() => _selected = 'voice-1'),
          ),
          const SizedBox(height: 10),
          _AudioChoice(
            selected: _selected == 'voice-2',
            onTap: () => setState(() => _selected = 'voice-2'),
          ),
        ],
      ),
      SubmissionMode.emoji => _emojiRow(['😺', '🚀', '🌈', '🤩', '🎉', '💪']),
      _ => _choiceList(['😺', '🚀', '🌈']),
    };
  }

  Widget _emojiRow(List<String> values) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values) ...[
            SizedBox(width: 84, child: _selectable(value)),
            if (value != values.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _choiceList(List<String> values) {
    return Column(
      children: [
        for (final value in values) ...[
          SizedBox(width: double.infinity, child: _selectable(value)),
          if (value != values.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _selectable(String value) {
    final selected = _selected == value;
    return InkWell(
      onTap: () => setState(() => _selected = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 58,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDAD9E2) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD9DAE4)),
        ),
        child: Text(
          value,
          style: GoogleFonts.inter(
            fontSize: value.length > 3 ? 13 : 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _setMode(SubmissionMode mode) {
    setState(() {
      _mode = mode;
      _selected = _defaultSelection(mode);
    });
  }

  String _defaultSelection(SubmissionMode mode) {
    return switch (mode) {
      SubmissionMode.text => 'Fun!',
      SubmissionMode.voice => 'voice-1',
      SubmissionMode.video => 'video-upload',
      SubmissionMode.screenshot => 'screenshot-upload',
      SubmissionMode.emoji => '😺',
    };
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;

  const _Chip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: selected ? Border.all(color: AppTheme.buttonColor) : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: selected ? AppTheme.buttonColor : const Color(0xFF1C1C21),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: _Chip(label: label, selected: selected),
    );
  }
}

class _AudioChoice extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AudioChoice({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow_rounded, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 4, color: AppTheme.buttonColor)),
            const SizedBox(width: 6),
            const Icon(
              Icons.headphones_rounded,
              size: 18,
              color: Color(0xFF777887),
            ),
          ],
        ),
      ),
    );
  }
}

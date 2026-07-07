import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TapBuddyPanel extends StatefulWidget {
  final VoidCallback onClose;

  const TapBuddyPanel({super.key, required this.onClose});

  @override
  State<TapBuddyPanel> createState() => _TapBuddyPanelState();
}

class _TapBuddyPanelState extends State<TapBuddyPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width < 560 ? (width * 0.82).clamp(292.0, 330.0) : 330.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: panelWidth,
          height: double.infinity,
          child: SafeArea(
            left: false,
            child: Column(
              children: [
                _PanelHeader(onClose: widget.onClose),
                const Divider(height: 1, color: Color(0xFFE8E8EF)),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 96, 14, 14),
                    children: const [
                      Center(child: _DatePill()),
                      SizedBox(height: 10),
                      _BuddyMessage('Hey there Champ!\nHow may I help you?'),
                      _BuddyMessage(
                        'Either type or click the button related for your help',
                      ),
                      _ChoiceRow(),
                      _UserMessage(
                        'Assignment kya karna hai bata do samajh nahi aaya',
                      ),
                      _BuddyMessage('Glad I could help! 😊'),
                      _BuddyMessage(
                        "Now let's get back to your Activity Video; watch till end with attention.\n\nYou can do this, Aarav!💪",
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: widget.onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B5BD6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                _InputBar(controller: _controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Image.asset('assets/onboarding/TAP-bot.png', width: 28, height: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAP Buddy',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C21),
                    ),
                  ),
                  Text(
                    'YOUR LEARNING DIDI',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF777887),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: const Color(0xFF777887),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F1F5),
                fixedSize: const Size(32, 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E4EA)),
      ),
      child: Text(
        'Today',
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BuddyMessage extends StatelessWidget {
  final String text;

  const _BuddyMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFF4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.35,
                  color: const Color(0xFF1C1C21),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.volume_up_rounded,
              size: 14,
              color: Color(0xFF5B5BD6),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  final String text;

  const _UserMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2E6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.35,
                  color: const Color(0xFF1C1C21),
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.done_rounded, size: 13, color: Color(0xFF58B77D)),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _ChoiceButton(label: 'Submission', active: true)),
          const SizedBox(width: 8),
          Expanded(child: _ChoiceButton(label: 'Quiz', active: false)),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool active;

  const _ChoiceButton({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF5B5BD6) : const Color(0xFFE5E4FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : const Color(0xFF4C4D65),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;

  const _InputBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.add_rounded, size: 18),
                  suffixIcon: const Icon(Icons.mood_rounded, size: 17),
                  hintText: 'Type here...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF9A9BA8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF5B5BD6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

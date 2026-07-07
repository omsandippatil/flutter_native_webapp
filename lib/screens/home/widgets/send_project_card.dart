import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'card_deck_wrapper.dart';
import 'reward_item.dart';

class SendProjectCard extends StatelessWidget {
  final String courseDisplay;
  final String unitName;
  final int points;
  final VoidCallback onSend;

  const SendProjectCard({
    super.key,
    required this.courseDisplay,
    required this.unitName,
    required this.points,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return CardDeckWrapper(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 34, 22, 26),
        child: Column(
          children: [
            _CardBody(
              courseDisplay: courseDisplay,
              unitName: unitName,
              points: points,
              badge: _TaskBadge(
                icon: Icons.info_outline_rounded,
                text: 'To do: Send project',
                background: const Color(0xFFFFF2D5),
                color: const Color(0xFF9E6C00),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B5BD6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Send my project',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SmallText('Send in '),
                _SmallText(
                  '2days 15hrs ',
                  color: const Color(0xFF159A58),
                  bold: true,
                ),
                _SmallText('and earn extra 2 '),
                const Icon(
                  Icons.diamond_rounded,
                  size: 14,
                  color: Color(0xFF5B5BD6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  final String courseDisplay;
  final String unitName;
  final int points;
  final Widget badge;

  const _CardBody({
    required this.courseDisplay,
    required this.unitName,
    required this.points,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Core $courseDisplay 1',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF747583),
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                unitName == 'States of Matter'
                    ? 'Get Ready for ScratchJr'
                    : unitName,
                style: GoogleFonts.inter(
                  fontSize: 27,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1C1C21),
                  height: 1.02,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 13),
              badge,
            ],
          ),
        ),
        const SizedBox(width: 16),
        _Rewards(points: points),
      ],
    );
  }
}

class _Rewards extends StatelessWidget {
  final int points;

  const _Rewards({required this.points});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You'll earn",
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF777887),
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          RewardItem(
            color: const Color(0xFFEAA43A),
            icon: Icons.star_rounded,
            text: '$points Points',
          ),
          const SizedBox(height: 10),
          const RewardItem(
            color: Color(0xFF28B36A),
            icon: Icons.local_fire_department,
            text: '1 streak',
          ),
          const SizedBox(height: 10),
          const RewardItem(
            color: Color(0xFF5B5BD6),
            icon: Icons.diamond_rounded,
            text: '1 skill gem',
          ),
        ],
      ),
    );
  }
}

class _TaskBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color background;
  final Color color;

  const _TaskBadge({
    required this.icon,
    required this.text,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallText extends StatelessWidget {
  final String text;
  final Color color;
  final bool bold;

  const _SmallText(
    this.text, {
    this.color = const Color(0xFF1C1C21),
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color,
        letterSpacing: 0,
      ),
    );
  }
}

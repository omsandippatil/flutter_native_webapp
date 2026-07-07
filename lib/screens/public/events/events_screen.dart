import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_nav.dart';

class EventItem {
  final String id;
  final String title;
  final String date;
  final String category;
  final String description;
  final String speaker;

  const EventItem({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    required this.description,
    required this.speaker,
  });
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  static const List<EventItem> _events = [
    EventItem(
      id: 'e1',
      title: 'ScratchJr Game Jam 2026',
      date: 'July 15, 2026 @ 4:00 PM',
      category: 'Hackathon',
      description:
          'Build your own creative game using ScratchJr coding blocks. Present it to industry mentors and win exciting prizes!',
      speaker: 'TAP Coding Mentors',
    ),
    EventItem(
      id: 'e2',
      title: 'Science Lab: States of Matter Live',
      date: 'July 22, 2026 @ 2:00 PM',
      category: 'Science',
      description:
          'Interact live with our science wizards as they conduct fun experiments showing gas sublimation and liquid density.',
      speaker: 'Dr. Alisha Roy',
    ),
    EventItem(
      id: 'e3',
      title: 'Art of Animation & Storyboarding',
      date: 'August 05, 2026 @ 5:00 PM',
      category: 'Arts',
      description:
          'Learn how to plan and storyboard your character animations before programming them. Recommended for all Class 5 students.',
      speaker: 'Siddharth Joshi (Lead Animator)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 800;

    return AppNav(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FA),
        body: Column(
          children: [
            AppHeader(
              title: 'Live Bootcamps & Events',
              points: 75,
              streakDay: 5,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : 20,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join Upcoming Live Sessions',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level up your skills by joining real-time sessions led by experts.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8E8E9F),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildEventCard(context, event),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventItem event) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8FB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.buttonColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  event.category,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.buttonColor,
                  ),
                ),
              ),
              Text(
                event.date,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8E8E9F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            event.title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6E6E7A),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF8E8E9F),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Led by: ${event.speaker}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8E8E9F),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/events/${event.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Join Info',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

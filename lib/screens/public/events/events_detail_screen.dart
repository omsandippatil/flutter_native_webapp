import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_header.dart';

class EventsDetailScreen extends StatefulWidget {
  final String id;

  const EventsDetailScreen({super.key, required this.id});

  @override
  State<EventsDetailScreen> createState() => _EventsDetailScreenState();
}

class _EventsDetailScreenState extends State<EventsDetailScreen> {
  bool _registered = false;
  bool _registering = false;

  @override
  Widget build(BuildContext context) {
    // Local lookup mock
    final String title = widget.id == 'e1'
        ? 'ScratchJr Game Jam 2026'
        : widget.id == 'e2'
        ? 'Science Lab: States of Matter Live'
        : 'Art of Animation & Storyboarding';

    final String category = widget.id == 'e1'
        ? 'Hackathon'
        : widget.id == 'e2'
        ? 'Science'
        : 'Arts';

    final String date = widget.id == 'e1'
        ? 'July 15, 2026 @ 4:00 PM'
        : widget.id == 'e2'
        ? 'July 22, 2026 @ 2:00 PM'
        : 'August 05, 2026 @ 5:00 PM';

    final String description = widget.id == 'e1'
        ? 'Build your own creative game using ScratchJr coding blocks. Present it to industry mentors and win exciting prizes!\n\nThis hackathon is open to all students enrolled in the ScratchJr course. You will build and submit a mini game and join a live demo session where you explain how your character blocks interact. The top 3 participants will win special coding certificates and gift hampers!'
        : widget.id == 'e2'
        ? 'Interact live with our science wizards as they conduct fun experiments showing gas sublimation and liquid density.\n\nSee water boil, ice expand, and dry gas fill balloon structures in real time! You will be able to ask questions live in chat and participate in a live poll. Ideal for students wrapping up the States of Matter core learning activity.'
        : 'Learn how to plan and storyboard your character animations before programming them. Recommended for all Class 5 students.\n\nIn this workshop, Siddharth Joshi will show you how to frame story cards, draw basic vector elements, and structure your motion triggers in logical sequences to make animations look smooth.';

    final String speaker = widget.id == 'e1'
        ? 'TAP Coding Mentors'
        : widget.id == 'e2'
        ? 'Dr. Alisha Roy'
        : 'Siddharth Joshi (Lead Animator)';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE8E8FB), height: 1.0),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1C1C21),
          ),
          onPressed: () => context.go('/events'),
        ),
        title: Text(
          'Event Details',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1C1C21),
          ),
        ),
      ),
      body: Column(
        children: [
          AppHeader(
            title: title,
            points: 75,
            streakDay: 5,
            showBack: true,
            onBack: () => context.go('/events'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5B5BD6), Color(0xFF8E8EEF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  date,
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      Text(
                        'About this Event',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF6E6E7A),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Speaker Profile',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8E8FB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: AppTheme.buttonColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            speaker,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C21),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Register button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _registering
                              ? null
                              : () async {
                                  if (_registered) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'You are already registered! Join details sent via SMS.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => _registering = true);
                                  await Future.delayed(
                                    const Duration(milliseconds: 1000),
                                  );
                                  if (!context.mounted) return;
                                  setState(() {
                                    _registering = false;
                                    _registered = true;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Registered successfully! 🎉 Check your dashboard for details.',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _registered
                                ? const Color(0xFF2ECC71)
                                : AppTheme.buttonColor,
                            foregroundColor: Colors.white,
                          ),
                          child: _registering
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  _registered
                                      ? 'Registered ✓'
                                      : 'Register for Session',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

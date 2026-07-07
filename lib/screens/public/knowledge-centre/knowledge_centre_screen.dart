import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_nav.dart';

class GuideItem {
  final String id;
  final String title;
  final String readTime;
  final String category;
  final String summary;

  const GuideItem({
    required this.id,
    required this.title,
    required this.readTime,
    required this.category,
    required this.summary,
  });
}

class KnowledgeCentreScreen extends StatelessWidget {
  const KnowledgeCentreScreen({super.key});

  static const List<GuideItem> _guides = [
    GuideItem(
      id: 'g1',
      title: 'Getting Started with ScratchJr Coding',
      readTime: '6 mins read',
      category: 'Coding',
      summary:
          'Learn the primary block groups: trigger, motion, control, and sound. Perfect helper for kids starting their coding journey.',
    ),
    GuideItem(
      id: 'g2',
      title: 'All About States of Matter: Study Guide',
      readTime: '8 mins read',
      category: 'Science',
      summary:
          'A complete handbook on particle arrangements, melting points, condensation, and everyday sublimation examples.',
    ),
    GuideItem(
      id: 'g3',
      title: 'Smart Saving: Financial Basics for Kids',
      readTime: '5 mins read',
      category: 'Financial Literacy',
      summary:
          'Understand the difference between needs and wants, how savings piggy-banks work, and setting monthly learning goals.',
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
            AppHeader(title: 'Knowledge Centre', points: 75, streakDay: 5),
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
                          'Handbooks & Reference Material',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Guides and resources to assist you in completing your weekly activities.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8E8E9F),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _guides.length,
                          itemBuilder: (context, index) {
                            final guide = _guides[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildGuideCard(context, guide),
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

  Widget _buildGuideCard(BuildContext context, GuideItem guide) {
    return InkWell(
      onTap: () => context.go('/knowledge-centre/${guide.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF45B0A9).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          guide.category,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF45B0A9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        guide.readTime,
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
                    guide.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guide.summary,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6E6E7A),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Center(
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFFBDC3C7),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

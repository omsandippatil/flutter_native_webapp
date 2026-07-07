import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_nav.dart';

class ProjectItem {
  final String id;
  final String title;
  final String author;
  final String school;
  final String course;
  final int likes;
  final String description;

  const ProjectItem({
    required this.id,
    required this.title,
    required this.author,
    required this.school,
    required this.course,
    required this.likes,
    required this.description,
  });
}

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key});

  static const List<ProjectItem> _projects = [
    ProjectItem(
      id: 'p1',
      title: 'Water Cycle Simulation Game',
      author: 'Ishaan Deshmukh',
      school: 'PPS Secondary Pune',
      course: 'Coding',
      likes: 142,
      description:
          'An interactive game in ScratchJr showing rain condensation, puddles filling up, and sun evaporation when tapped!',
    ),
    ProjectItem(
      id: 'p2',
      title: 'Solids Liquids Gas Sorting Box',
      author: 'Ananya Iyer',
      school: 'MCD Primary Delhi',
      course: 'Science',
      likes: 98,
      description:
          'A custom sorting game where users categorize particles into solid containers, liquid jars, or gas balloons.',
    ),
    ProjectItem(
      id: 'p3',
      title: 'My Weekly Budget Piggy Bank',
      author: 'Rohit Kulkarni',
      school: 'Zilla Parishad School',
      course: 'Financial Literacy',
      likes: 54,
      description:
          'A mock project showing savings logs and wants charts created on story cards. Help kids understand piggy savings.',
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
              title: 'Student Project Showcase',
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
                          'Outstanding Student Creations',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Draw inspiration from projects built by kids across TAP Academy.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8E8E9F),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _projects.length,
                          itemBuilder: (context, index) {
                            final proj = _projects[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildProjectCard(context, proj),
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

  Widget _buildProjectCard(BuildContext context, ProjectItem proj) {
    return InkWell(
      onTap: () => context.go('/projects/${proj.id}'),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: Color(0xFFF5B041),
                size: 36,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5B041).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          proj.course,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF5B041),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.favorite_rounded,
                        color: Colors.redAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${proj.likes}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8E8E9F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    proj.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By ${proj.author} • ${proj.school}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8E8E9F),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_header.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String id;

  const ProjectDetailScreen({super.key, required this.id});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _liked = false;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.id == 'p1'
        ? 142
        : widget.id == 'p2'
        ? 98
        : 54;
  }

  @override
  Widget build(BuildContext context) {
    // Local lookup mock
    final String title = widget.id == 'p1'
        ? 'Water Cycle Simulation Game'
        : widget.id == 'p2'
        ? 'Solids Liquids Gas Sorting Box'
        : 'My Weekly Budget Piggy Bank';

    final String author = widget.id == 'p1'
        ? 'Ishaan Deshmukh'
        : widget.id == 'p2'
        ? 'Ananya Iyer'
        : 'Rohit Kulkarni';

    final String school = widget.id == 'p1'
        ? 'PPS Secondary Pune'
        : widget.id == 'p2'
        ? 'MCD Primary Delhi'
        : 'Zilla Parishad School';

    final String course = widget.id == 'p1'
        ? 'Coding'
        : widget.id == 'p2'
        ? 'Science'
        : 'Financial Literacy';

    final String description = widget.id == 'p1'
        ? 'An interactive game in ScratchJr showing rain condensation, puddles filling up, and sun evaporation when tapped!\n\nI built this because I wanted to show my friends how clouds are made from steam particles. In the game, you can click the cloud to make it rain, click the sun to raise the temperature, and see the water levels change!'
        : widget.id == 'p2'
        ? 'A custom sorting game where users categorize particles into solid containers, liquid jars, or gas balloons.\n\nThis project contains drag-and-drop mechanics. If you drop a solid item like an apple into the solid jar, it rings a happy bell sound! If you drop water into the balloon, it says "Oops!" and lets you try again.'
        : 'A mock project showing savings logs and wants charts created on story cards. Help kids understand piggy savings.\n\nI created a paper folder with custom slots: Save, Spend, and Give. I tracked all my small pocket money for 4 weeks and designed cards representing my savings targets (like buying drawing pens).';

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
          onPressed: () => context.go('/projects'),
        ),
        title: Text(
          'View Project',
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
            onBack: () => context.go('/projects'),
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
                      // Project visual mockup card
                      Container(
                        width: double.infinity,
                        height: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Opacity(
                              opacity: 0.35,
                              child: Icon(
                                Icons.rocket_launch_rounded,
                                size: 96,
                                color: Colors.white70,
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              left: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Built with TAP $course Toolkit',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Created by $author • $school',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8E8E9F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            onPressed: () {
                              setState(() {
                                _liked = !_liked;
                                if (_liked) {
                                  _likesCount++;
                                } else {
                                  _likesCount--;
                                }
                              });
                            },
                            icon: Icon(
                              _liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: _liked ? Colors.red : Colors.grey,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: _liked
                                  ? const Color(0xFFFDEDEC)
                                  : const Color(0xFFF1F1F5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_likesCount Likes',
                        style: GoogleFonts.spaceMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8E8E9F),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE8E8FB)),
                      const SizedBox(height: 20),

                      Text(
                        'Project Description',
                        style: GoogleFonts.inter(
                          fontSize: 15,
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
                          height: 1.6,
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

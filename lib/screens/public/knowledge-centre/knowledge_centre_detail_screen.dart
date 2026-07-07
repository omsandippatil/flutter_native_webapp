import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_header.dart';

class KnowledgeCentreDetailScreen extends StatelessWidget {
  final String id;

  const KnowledgeCentreDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    // Local lookup mock
    final String title = id == 'g1'
        ? 'Getting Started with ScratchJr Coding'
        : id == 'g2'
        ? 'All About States of Matter: Study Guide'
        : 'Smart Saving: Financial Basics for Kids';

    final String readTime = id == 'g1'
        ? '6 mins read'
        : id == 'g2'
        ? '8 mins read'
        : '5 mins read';

    final String content = id == 'g1'
        ? 'ScratchJr is an introductory programming language that enables young children to create their own interactive stories and games.\n\nCharacters are called "Sprites". You control sprites by snapping blocks together in the programming area:\n\n1. Trigger Blocks: The Yellow blocks. The "Green Flag" starts the program. The "Tap Sprite" starts when clicked.\n\n2. Motion Blocks: The Blue blocks. Used to move sprites left, right, up, down, or make them rotate/hop.\n\n3. Looks Blocks: The Purple blocks. Used to display speeches, grow, shrink, or hide/reveal sprites.\n\n4. Control Blocks: The Orange blocks. Contain timers and loop repeat counts.'
        : id == 'g2'
        ? 'Everything surrounding us is made of matter. Matter is anything that has mass and takes up space.\n\nThere are three main states of matter we observe daily:\n\n1. Solids: Particles are tightly packed in a regular arrangement. Solids have a fixed shape and fixed volume (e.g. Ice, rocks, iron).\n\n2. Liquids: Particles are close together but have no fixed structure. They can slide past each other. Liquids have a fixed volume but take the shape of the container (e.g. Water, oil).\n\n3. Gases: Particles are spread very far apart with no fixed arrangement. They move rapidly in all directions and fill the entire space of their container (e.g. Steam, air, helium).'
        : 'Saving means keeping money aside for the future instead of spending all of it today.\n\nKey Concepts:\n\n1. Needs vs. Wants: A need is something you must have to live (like healthy food, shelter, schoolbooks). A want is something nice to have but you can live without (like toys, video games, candy).\n\n2. Piggy Banks: An excellent first step. Every time you receive pocket money, put 50% into savings and use the remaining 50% for tiny wants.\n\n3. Setting Goals: If you want a new set of sketch pens, calculate how much it costs and save a small amount daily until you reach the target.';

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
          onPressed: () => context.go('/knowledge-centre'),
        ),
        title: Text(
          'Read Guide',
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
            onBack: () => context.go('/knowledge-centre'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE8E8FB)),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              color: AppTheme.buttonColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              readTime,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.buttonColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFE8E8FB)),
                        const SizedBox(height: 20),
                        Text(
                          content,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: const Color(0xFF4C4C56),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
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

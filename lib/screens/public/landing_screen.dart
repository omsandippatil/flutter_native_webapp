import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Illustration
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.buttonColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: AppTheme.buttonColor,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title & Tagline
                  Text(
                    'Welcome to TAP',
                    style: GoogleFonts.inter(
                      fontSize: isDesktop ? 36 : 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The Academy of Progress',
                    style: GoogleFonts.inter(
                      fontSize: isDesktop ? 20 : 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6E6E7A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Learn science, coding, arts and financial literacy through weekly interactive video lessons, quizzes, and cool hands-on projects!',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF8E8E9F),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Call to Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.login),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.buttonColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Get Started / Enroll Now',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.welcomeBack),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE8E8FB), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Already Enrolled? Login',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.buttonColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Small Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logos/gov-logo.png', height: 28, errorBuilder: (context, error, stackTrace) => const SizedBox.shrink()),
                      const SizedBox(width: 8),
                      Image.asset('assets/logos/tap_logo.png', height: 24, errorBuilder: (context, error, stackTrace) => const SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

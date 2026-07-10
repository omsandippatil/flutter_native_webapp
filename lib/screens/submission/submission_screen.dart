import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/activity_provider.dart';

class SubmissionScreen extends ConsumerStatefulWidget {
  const SubmissionScreen({super.key});

  @override
  ConsumerState<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends ConsumerState<SubmissionScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isUploading = false;
  String? _selectedFileName;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _simulateFileUpload() async {
    setState(() => _isUploading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _isUploading = false;
        _selectedFileName = 'scratch_jr_game_states_of_matter.png';
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(learningDashboardProvider);

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1C1C21)),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text(
          'Submit Project',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C21)),
        ),
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.buttonColor)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (dashboard) {
          final unit = dashboard.unit;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit context card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E8FB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Core Science 1 • Submission',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8E8E9F),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  unit.unitName,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1C1C21),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${unit.submissionPoints} pts',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF2ECC71),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Prompt text
                    Text(
                      'Submission Guidelines',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C21),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      unit.submissionPrompt,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF6E6E7A),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // File upload area
                    if (_selectedFileName == null)
                      GestureDetector(
                        onTap: _isUploading ? null : _simulateFileUpload,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.buttonColor.withValues(alpha: 0.3),
                              width: 2,
                              style: BorderStyle.solid, // solid fallback for dashed border visual
                            ),
                          ),
                          child: Center(
                            child: _isUploading
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: AppTheme.buttonColor),
                                      SizedBox(height: 16),
                                      Text(
                                        'Uploading project files...',
                                        style: TextStyle(color: Color(0xFF6E6E7A), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload_outlined, color: AppTheme.buttonColor, size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Click to upload project files',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1C1C21),
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Supports PNG, JPG, or MP4',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF8E8E9F),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE8E8FB)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E8FB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.image_rounded, color: AppTheme.buttonColor),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFileName!,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1C1C21),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '1.2 MB • Ready to submit',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8E8E9F),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _selectedFileName = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                    // Comment text area
                    Text(
                      'Tell us about your project',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C21),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'What did you enjoy building? Explain how it works...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFFBDC3C7), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE8E8FB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE8E8FB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.buttonColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_selectedFileName == null || _submitting)
                            ? null
                            : () async {
                                setState(() => _submitting = true);
                                await Future.delayed(const Duration(milliseconds: 1200));
                                if (!context.mounted) return;
                                ref.read(learningDashboardProvider.notifier).submitProject();
                                setState(() => _submitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Project submitted successfully! 🚀'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                context.go(AppRoutes.home);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.buttonColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFBDC3C7),
                        ),
                        child: _submitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Submit Project',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

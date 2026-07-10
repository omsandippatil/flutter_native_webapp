import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/activity_provider.dart';

class QuizQuestion {
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;

  const QuizQuestion({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
  });
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  static const List<QuizQuestion> _questions = [
    QuizQuestion(
      questionText: 'Which of the following is NOT one of the three primary states of matter?',
      options: ['Solid', 'Liquid', 'Energy', 'Gas'],
      correctAnswerIndex: 2,
    ),
    QuizQuestion(
      questionText: 'What happens to water particles when you heat them up?',
      options: [
        'They slow down and group together',
        'They move faster and spread apart',
        'They disappear completely',
        'They grow heavier'
      ],
      correctAnswerIndex: 1,
    ),
    QuizQuestion(
      questionText: 'In ScratchJr, which trigger block is used to start a script when the user taps on a character?',
      options: [
        'Start on Green Flag block',
        'Start on Tap character block',
        'Start on Orange block',
        'Blue Move block'
      ],
      correctAnswerIndex: 1,
    ),
  ];

  int _currentIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasSubmitted = false;
  int _score = 0;
  bool _quizComplete = false;

  void _submitAnswer() {
    if (_selectedAnswerIndex == null) return;

    setState(() {
      _hasSubmitted = true;
      if (_selectedAnswerIndex == _questions[_currentIndex].correctAnswerIndex) {
        _score++;
      }
    });
  }

  void _nextStep() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
        _hasSubmitted = false;
      });
    } else {
      setState(() {
        _quizComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_currentIndex + 1) / _questions.length;

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
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1C1C21)),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text(
          'Quiz Time',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C21)),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _quizComplete ? _buildScoreCard() : _buildQuizBody(progress),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizBody(double progressPercent) {
    final question = _questions[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Tracker Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8E8E9F),
                ),
              ),
              Text(
                'Score: $_score',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.buttonColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8E8FB),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.buttonColor),
            ),
          ),
          const SizedBox(height: 32),
          // Question text card
          Text(
            question.questionText,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C21),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // Options
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final optionText = question.options[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildOptionTile(index, optionText, question),
                );
              },
            ),
          ),
          // Action button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedAnswerIndex == null
                  ? null
                  : (_hasSubmitted ? _nextStep : _submitAnswer),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFBDC3C7),
              ),
              child: Text(
                _hasSubmitted
                    ? (_currentIndex == _questions.length - 1 ? 'Finish' : 'Next Question')
                    : 'Submit Answer',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(int index, String text, QuizQuestion question) {
    final isSelected = _selectedAnswerIndex == index;
    final isCorrect = question.correctAnswerIndex == index;

    Color tileColor = Colors.white;
    Color borderTileColor = const Color(0xFFE8E8FB);
    Widget? trailingIcon;

    if (_hasSubmitted) {
      if (isCorrect) {
        tileColor = const Color(0xFFD4EFDF);
        borderTileColor = const Color(0xFF2ECC71);
        trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71));
      } else if (isSelected) {
        tileColor = const Color(0xFFFADBD8);
        borderTileColor = const Color(0xFFE74C3C);
        trailingIcon = const Icon(Icons.cancel_rounded, color: Color(0xFFE74C3C));
      }
    } else if (isSelected) {
      tileColor = const Color(0xFFE8E8FB);
      borderTileColor = AppTheme.buttonColor;
    }

    return GestureDetector(
      onTap: _hasSubmitted
          ? null
          : () {
              setState(() {
                _selectedAnswerIndex = index;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderTileColor, width: isSelected || _hasSubmitted ? 2.0 : 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.buttonColor : const Color(0xFFF1F1F5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF7E7E8A),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C21),
                ),
              ),
            ),
            ?trailingIcon,
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final earnedGems = _score == _questions.length ? 1 : 0;
    final earnedPoints = _score * 5;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success graphic
          Image.asset(
            'assets/onboarding/sussess_celebrate.png',
            height: 160,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.stars_rounded,
              size: 120,
              color: Color(0xFFF5B041),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _score == _questions.length ? 'Perfect Score! 🏆' : 'Great Job! 👏',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C21),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You answered $_score of ${_questions.length} questions correctly.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF6E6E7A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Rewards Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8E8FB)),
            ),
            child: Column(
              children: [
                Text(
                  'REWARDS EARNED',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8E8E9F),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRewardBadge(Icons.star_rounded, const Color(0xFFF5B041), '+$earnedPoints', 'Points'),
                    _buildRewardBadge(Icons.local_fire_department_rounded, const Color(0xFF2ECC71), '+1', 'Streak'),
                    _buildRewardBadge(Icons.diamond_rounded, AppTheme.buttonColor, '+$earnedGems', 'Skill Gem'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Continue button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                ref.read(learningDashboardProvider.notifier).completeQuiz();
                context.go(AppRoutes.home);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Complete & Claim',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardBadge(IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C21)),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8E8E9F)),
        ),
      ],
    );
  }
}

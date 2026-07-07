import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../models/activity_models.dart';
import '../../providers/activity_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/loading_view.dart';
import 'widgets/completed_card.dart';
import 'widgets/home_buddy_art.dart';
import 'widgets/quiz_pending_card.dart';
import 'widgets/send_project_card.dart';
import 'widgets/start_activity_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(learningDashboardProvider);

    return AppNav(
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        body: dashboardAsync.when(
          loading: () => const LoadingView(),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load dashboard: $err',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(learningDashboardProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (dashboard) => _HomeDashboard(dashboard: dashboard),
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  final LearningDashboard dashboard;

  const _HomeDashboard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final progress = dashboard.progress;
    final stage = progress.currentStage;
    final unit = dashboard.unit;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final horizontalPadding = switch (constraints.maxWidth) {
          >= 980 => 24.0,
          >= 640 => 20.0,
          _ => 16.0,
        };

        return SafeArea(
          bottom: false,
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 1060),
              color: Colors.white,
              child: Column(
                children: [
                  AppHeader(
                    title: 'Home',
                    studentName: progress.studentName,
                    points: progress.points,
                    streakDay: progress.streakDay,
                    showAskBuddy: true,
                    showStudentSummary: true,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        isWide ? 54 : 28,
                        horizontalPadding,
                        34,
                      ),
                      child: _StageContent(
                        stage: stage,
                        unit: unit,
                        isWide: isWide,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StageContent extends StatelessWidget {
  final LearningStage stage;
  final CourseUnit unit;
  final bool isWide;

  const _StageContent({
    required this.stage,
    required this.unit,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    if (stage == LearningStage.completed) {
      return _CompletedStage(unit: unit, isWide: isWide);
    }

    final card = _ActiveCard(stage: stage, unit: unit);
    final artHeight = stage == LearningStage.startActivity ? 350.0 : 310.0;

    if (!isWide) {
      return Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: card,
          ),
          const SizedBox(height: 22),
          HomeBuddyArt(stage: stage, maxHeight: 280),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 11,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: card,
          ),
        ),
        const SizedBox(width: 42),
        Flexible(
          flex: 8,
          child: Align(
            alignment: Alignment.topCenter,
            child: HomeBuddyArt(stage: stage, maxHeight: artHeight),
          ),
        ),
      ],
    );
  }
}

class _CompletedStage extends StatelessWidget {
  final CourseUnit unit;
  final bool isWide;

  const _CompletedStage({required this.unit, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final card = CompletedCard(points: unit.totalPoints);

    if (!isWide) {
      return Column(
        children: [
          HomeBuddyArt(stage: LearningStage.completed, maxHeight: 220),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: card,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Flexible(
          flex: 5,
          child: Align(
            alignment: Alignment.topRight,
            child: HomeBuddyArt(stage: LearningStage.completed, maxHeight: 270),
          ),
        ),
        const SizedBox(width: 36),
        Flexible(
          flex: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: card,
          ),
        ),
        const SizedBox(width: 36),
        const Flexible(
          flex: 5,
          child: Align(
            alignment: Alignment.topLeft,
            child: HomeBuddyArt(stage: LearningStage.completed, maxHeight: 270),
          ),
        ),
      ],
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final LearningStage stage;
  final CourseUnit unit;

  const _ActiveCard({required this.stage, required this.unit});

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      LearningStage.startActivity => StartActivityCard(
        courseDisplay: unit.courseDisplay,
        unitName: unit.unitName,
        points: unit.videoPoints,
        onStart: () => context.go(AppRoutes.classroom),
      ),
      LearningStage.sendProject => SendProjectCard(
        courseDisplay: unit.courseDisplay,
        unitName: unit.unitName,
        points: unit.submissionPoints,
        onSend: () => context.go(AppRoutes.classroom),
      ),
      LearningStage.quizPending => QuizPendingCard(
        courseDisplay: unit.courseDisplay,
        unitName: unit.unitName,
        points: 5,
        onStartQuiz: () => context.go(AppRoutes.classroom),
      ),
      LearningStage.completed => CompletedCard(points: unit.totalPoints),
    };
  }
}

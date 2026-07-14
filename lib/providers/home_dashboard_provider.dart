import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/active_profile_model.dart';
import '../data/models/enrollment_model.dart';
import '../data/models/learner_state_model.dart';
import '../models/activity_models.dart';
import 'learner_state_provider.dart';
import 'profile_provider.dart';
import 'program_content_provider.dart';

class NoActiveProfileException implements Exception {
  const NoActiveProfileException();

  @override
  String toString() => 'No active profile is selected.';
}

class NoEnrollmentException implements Exception {
  const NoEnrollmentException();

  @override
  String toString() => 'This profile has no active course enrollment.';
}

int _resolveUnitIndex(EnrollmentModel enrollment, int totalUnits) {
  final furthest = [
    enrollment.videosCompleted,
    enrollment.quizzesCompleted,
    enrollment.submissionIndex,
  ].reduce((a, b) => a > b ? a : b);
  if (totalUnits == 0) return 0;
  return furthest >= totalUnits ? totalUnits - 1 : furthest;
}

LearningProgress _buildProgress({
  required ActiveProfileModel profile,
  required LearnerStateModel learnerState,
  required EnrollmentModel enrollment,
  required int unitIndex,
}) {
  final unitComplete = unitIndex < enrollment.videosCompleted &&
      unitIndex < enrollment.quizzesCompleted &&
      unitIndex < enrollment.submissionIndex;

  return LearningProgress(
    studentName: learnerState.profile?.studentName ?? profile.studentName ?? 'Champ',
    points: learnerState.xp ?? 0,
    skillGems: learnerState.submissionGems ?? 0,
    streakDay: learnerState.streak ?? 0,
    videoDone: unitComplete || enrollment.videosCompleted > unitIndex,
    submissionDone: unitComplete || enrollment.submissionIndex > unitIndex,
    quizDone: unitComplete || enrollment.quizzesCompleted > unitIndex,
    watchedVideosThisWeek: learnerState.unitsCompletedThisWeek ?? 0,
  );
}

final learningDashboardProvider = FutureProvider.autoDispose<LearningDashboard>((ref) async {
  final activeProfile = await ref.watch(activeProfileProvider.future);
  if (activeProfile == null) {
    throw const NoActiveProfileException();
  }

  final learnerState = await ref.watch(
    learnerStateDataProvider(activeProfile.learnerId).future,
  );

  final enrollment = learnerState.enrollment;
  if (enrollment == null || enrollment.course == null) {
    return LearningDashboard(
      progress: _buildProgress(
        profile: activeProfile,
        learnerState: learnerState,
        enrollment: const EnrollmentModel(),
        unitIndex: 0,
      ),
      unit: null,
      hasEnrollment: false,
      hasReachedWeeklyCap: learnerState.isBingeing ?? false,
    );
  }

  final course = await ref.watch(
    courseDetailDataProvider(enrollment.course!).future,
  );

  if (course.units.isEmpty) {
    return LearningDashboard(
      progress: _buildProgress(
        profile: activeProfile,
        learnerState: learnerState,
        enrollment: enrollment,
        unitIndex: 0,
      ),
      unit: null,
      hasEnrollment: true,
      hasReachedWeeklyCap: learnerState.isBingeing ?? false,
    );
  }

  final unitIndex = _resolveUnitIndex(enrollment, course.units.length);
  final progress = _buildProgress(
    profile: activeProfile,
    learnerState: learnerState,
    enrollment: enrollment,
    unitIndex: unitIndex,
  );

  final allUnitsDone = unitIndex >= course.units.length - 1 &&
      progress.videoDone &&
      progress.submissionDone &&
      progress.quizDone;

  return LearningDashboard(
    progress: progress,
    unit: allUnitsDone ? null : CourseUnit.fromCourse(course, unitIndex),
    hasEnrollment: true,
    hasReachedWeeklyCap: learnerState.isBingeing ?? false,
  );
});
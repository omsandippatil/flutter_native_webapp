import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/active_profile_model.dart';
import '../models/enrollment_model.dart';
import '../models/learner_state_model.dart';
import '../models/activity_models.dart';
import '../models/classroom_progress_stage.dart';
import '../models/program_content/course_detail_model.dart';
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

LearningProgress _buildProgress({
  required ActiveProfileModel profile,
  required LearnerStateModel learnerState,
  required EnrollmentModel enrollment,
  required int unitIndex,
  CourseUnitModel? unit,
}) {
  final snapshot = ClassroomProgressResolver.resolve(
    enrollment: enrollment,
    unitIndex: unitIndex,
    unit: unit,
    learnerSubmissionIndex: learnerState.submissionIndex,
  );

  return LearningProgress(
    studentName:
        learnerState.profile?.studentName ?? profile.studentName ?? 'Champ',
    points: learnerState.xp ?? 0,
    skillGems: learnerState.submissionGems ?? 0,
    streakDay: learnerState.streak ?? 0,
    videoDone: snapshot.videoDone,
    submissionDone: snapshot.submissionDone,
    quizDone: snapshot.quizDone,
    classroomStage: snapshot.stage,
    watchedVideosThisWeek: learnerState.unitsCompletedThisWeek ?? 0,
  );
}

final learningDashboardProvider = FutureProvider.autoDispose<LearningDashboard>(
  (ref) async {
    final activeProfile = await ref.watch(activeProfileProvider.future);
    if (activeProfile == null) {
      throw const NoActiveProfileException();
    }

    var learnerState = await ref.watch(
      learnerStateDataProvider(activeProfile.learnerId).future,
    );

    var enrollment = learnerState.enrollment;
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

    final unitIndex = ClassroomProgressResolver.resolveUnitIndexForCourse(
      enrollment,
      course.units,
      learnerSubmissionIndex: learnerState.submissionIndex,
    );
    final courseUnit = course.units[unitIndex];
    var progress = _buildProgress(
      profile: activeProfile,
      learnerState: learnerState,
      enrollment: enrollment,
      unitIndex: unitIndex,
      unit: courseUnit,
    );

    if (!learnerState.hasPendingLocalProgress &&
        progress.classroomStage != ClassroomProgressStage.watchVideo &&
        progress.classroomStage != ClassroomProgressStage.unitCompleted) {
      final repository = await ref.read(learnerStateRepositoryProvider.future);
      learnerState = await repository.prepareLocalUnit(
        learnerId: activeProfile.learnerId,
        unitIndex: unitIndex,
      );
      enrollment = learnerState.enrollment!;
      progress = _buildProgress(
        profile: activeProfile,
        learnerState: learnerState,
        enrollment: enrollment,
        unitIndex: unitIndex,
        unit: courseUnit,
      );
    }

    final allUnitsDone =
        unitIndex >= course.units.length - 1 &&
        progress.videoDone &&
        progress.submissionDone &&
        progress.quizDone;
    final learnerStateRepository = await ref.read(
      learnerStateRepositoryProvider.future,
    );
    final celebration = learnerStateRepository.readHomeCelebration(
      activeProfile.learnerId,
    );

    return LearningDashboard(
      progress: progress,
      unit: allUnitsDone ? null : CourseUnit.fromCourse(course, unitIndex),
      hasEnrollment: true,
      hasReachedWeeklyCap: learnerState.isBingeing ?? false,
      showCompletionCelebration: celebration?['show'] == true,
      completionPoints: (celebration?['points'] as num?)?.toInt() ?? 0,
    );
  },
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/features/classroom/models/progress_stage.dart';
import 'package:tapapp/domain/learner/models/learner_state.dart';
import 'package:tapapp/domain/course/models/course_detail.dart';
import 'package:tapapp/features/classroom/data/session_window_repository.dart';
import 'package:tapapp/domain/learner/providers/learner_state_providers.dart';
import 'package:tapapp/providers/local_cache_provider.dart';
import 'package:tapapp/domain/profile/providers/profile_providers.dart';
import 'package:tapapp/domain/course/providers/course_providers.dart';

class NoActiveEnrollmentException implements Exception {
  const NoActiveEnrollmentException();

  @override
  String toString() => 'No active course enrollment for this profile.';
}

final classSessionWindowRepositoryProvider =
    FutureProvider<ClassSessionWindowRepository>((ref) async {
      final localCache = await ref.watch(localCacheProvider.future);
      return ClassSessionWindowRepository(localCache);
    });

class ClassSessionBootstrap {
  const ClassSessionBootstrap({
    required this.learnerId,
    required this.phone,
    required this.learnerState,
    required this.courseName,
    required this.unit,
    required this.nextUnit,
    required this.unitIndex,
    required this.weeklyCapAlreadyReached,
  });

  final String learnerId;
  final String phone;
  final LearnerStateModel learnerState;
  final String courseName;
  final CourseUnitModel? unit;
  final CourseUnitModel? nextUnit;
  final int unitIndex;
  final bool weeklyCapAlreadyReached;
}

final classSessionBootstrapProvider =
    FutureProvider.autoDispose<ClassSessionBootstrap>((ref) async {
      final activeProfile = await ref.watch(activeProfileProvider.future);
      if (activeProfile == null) {
        throw StateError('No active profile selected.');
      }

      final learnerStateRepository = await ref.watch(
        learnerStateRepositoryProvider.future,
      );

      var learnerState = await learnerStateRepository.fetchState(
        learnerId: activeProfile.learnerId,
      );

      if (!learnerState.hasReachedWeeklyActivityLimit() &&
          learnerState.hasPendingLocalProgress) {
        final synced = await learnerStateRepository.syncCompletedLocalProgress(
          activeProfile.learnerId,
        );
        if (synced != null) learnerState = synced;
      }

      final sessionWindowRepository = await ref.watch(
        classSessionWindowRepositoryProvider.future,
      );
      final localCompleted = sessionWindowRepository
          .completedUnitCountThisWindow(
            activeProfile.learnerId,
            learnerState.windowStartDate,
          );

      var enrollment = learnerState.enrollment;
      if (enrollment == null || enrollment.course == null) {
        throw const NoActiveEnrollmentException();
      }

      final course = await ref.watch(
        courseDetailDataProvider(enrollment.course!).future,
      );
      if (course.units.isEmpty) {
        return ClassSessionBootstrap(
          learnerId: activeProfile.learnerId,
          phone: activeProfile.phone,
          learnerState: learnerState,
          courseName: course.name,
          unit: null,
          nextUnit: null,
          unitIndex: 0,
          weeklyCapAlreadyReached: true,
        );
      }

      final startIndex = ClassroomProgressResolver.resolveUnitIndexForCourse(
        enrollment,
        course.units,
      );
      final selectedUnit = course.units[startIndex];
      final nextUnit = startIndex + 1 < course.units.length
          ? course.units[startIndex + 1]
          : null;
      var selectedProgress = ClassroomProgressResolver.resolve(
        enrollment: enrollment,
        unitIndex: startIndex,
        unit: selectedUnit,
      );

      if (!learnerState.hasPendingLocalProgress &&
          selectedProgress.stage != ClassroomProgressStage.watchVideo &&
          selectedProgress.stage != ClassroomProgressStage.unitCompleted) {
        learnerState = await learnerStateRepository.prepareLocalUnit(
          learnerId: activeProfile.learnerId,
          unitIndex: startIndex,
        );
        enrollment = learnerState.enrollment!;
        selectedProgress = ClassroomProgressResolver.resolve(
          enrollment: enrollment,
          unitIndex: startIndex,
          unit: selectedUnit,
        );
      }
      final capReached = learnerState.hasReachedWeeklyActivityLimit(
        localCompleted: localCompleted,
      );

      if (capReached &&
          selectedProgress.stage == ClassroomProgressStage.watchVideo) {
        return ClassSessionBootstrap(
          learnerId: activeProfile.learnerId,
          phone: activeProfile.phone,
          learnerState: learnerState,
          courseName: course.name,
          unit: null,
          nextUnit: nextUnit,
          unitIndex: startIndex,
          weeklyCapAlreadyReached: true,
        );
      }

      if (selectedProgress.stage != ClassroomProgressStage.unitCompleted) {
        return ClassSessionBootstrap(
          learnerId: activeProfile.learnerId,
          phone: activeProfile.phone,
          learnerState: learnerState,
          courseName: course.name,
          unit: selectedUnit,
          nextUnit: nextUnit,
          unitIndex: startIndex,
          weeklyCapAlreadyReached: false,
        );
      }

      if (capReached) {
        return ClassSessionBootstrap(
          learnerId: activeProfile.learnerId,
          phone: activeProfile.phone,
          learnerState: learnerState,
          courseName: course.name,
          unit: null,
          nextUnit: nextUnit,
          unitIndex: startIndex,
          weeklyCapAlreadyReached: true,
        );
      }

      return ClassSessionBootstrap(
        learnerId: activeProfile.learnerId,
        phone: activeProfile.phone,
        learnerState: learnerState,
        courseName: course.name,
        unit: selectedUnit,
        nextUnit: nextUnit,
        unitIndex: startIndex,
        weeklyCapAlreadyReached: false,
      );
    });

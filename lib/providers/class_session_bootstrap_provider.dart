import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/classroom_progress_stage.dart';
import '../models/learner_state_model.dart';
import '../models/program_content/course_detail_model.dart';
import 'class_session_window_repository.dart';
import 'learner_state_provider.dart';
import 'local_cache_provider.dart';
import 'profile_provider.dart';
import 'program_content_provider.dart';

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
    required this.unitIndex,
    required this.weeklyCapAlreadyReached,
  });

  final String learnerId;
  final String phone;
  final LearnerStateModel learnerState;
  final String courseName;
  final CourseUnitModel? unit;
  final int unitIndex;
  final bool weeklyCapAlreadyReached;
}

/// The server is the only source of truth for whether the weekly cap has
/// been hit. `is_bingeing` and `activities_remaining` are computed
/// server-side from the learner's actual window state; a local unit-count
/// guess (`maxWeeklyUnits ?? 2`) can drift from that and either let the
/// student through when they shouldn't be, or block them one unit early.
bool _serverSaysCapReached(LearnerStateModel state) {
  final bingeing = state.isBingeing ?? false;
  final remaining = state.unitsRemaining;
  return bingeing || (remaining != null && remaining <= 0);
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

      // Always start a new session from a freshly-fetched state, not the cached
      // one. The cached copy may predate the most recent unit completion (or a
      // completion made from another device), and a stale "not bingeing" read
      // here is exactly what lets a student slip past the weekly cap.
      final learnerState = await learnerStateRepository.fetchState(
        learnerId: activeProfile.learnerId,
        forceRefresh: true,
      );

      final enrollment = learnerState.enrollment;
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
          unitIndex: 0,
          weeklyCapAlreadyReached: true,
        );
      }

      final startIndex = ClassroomProgressResolver.resolveUnitIndexForCourse(
        enrollment,
        course.units,
      );
      final selectedUnit = course.units[startIndex];
      final selectedProgress = ClassroomProgressResolver.resolve(
        enrollment: enrollment,
        unitIndex: startIndex,
        unit: selectedUnit,
      );
      final capReached = _serverSaysCapReached(learnerState);

      if (selectedProgress.stage != ClassroomProgressStage.unitCompleted) {
        return ClassSessionBootstrap(
          learnerId: activeProfile.learnerId,
          phone: activeProfile.phone,
          learnerState: learnerState,
          courseName: course.name,
          unit: selectedUnit,
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
        unitIndex: startIndex,
        weeklyCapAlreadyReached: false,
      );
    });

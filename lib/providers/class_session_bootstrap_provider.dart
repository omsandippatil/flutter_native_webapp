import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enrollment_model.dart';
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

final classSessionWindowRepositoryProvider = FutureProvider<ClassSessionWindowRepository>((ref) async {
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

int _resolveUnitIndex(EnrollmentModel enrollment, int totalUnits) {
  final furthest = [
    enrollment.videosCompleted,
    enrollment.quizzesCompleted,
    enrollment.submissionIndex,
  ].reduce((a, b) => a > b ? a : b);
  if (totalUnits == 0) return 0;
  return furthest >= totalUnits ? totalUnits - 1 : furthest;
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

final classSessionBootstrapProvider = FutureProvider.autoDispose<ClassSessionBootstrap>((ref) async {
  final activeProfile = await ref.watch(activeProfileProvider.future);
  if (activeProfile == null) {
    throw StateError('No active profile selected.');
  }

  final learnerStateRepository = await ref.watch(learnerStateRepositoryProvider.future);

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

  final course = await ref.watch(courseDetailDataProvider(enrollment.course!).future);
  final sessionWindowRepository = await ref.watch(classSessionWindowRepositoryProvider.future);

  if (_serverSaysCapReached(learnerState) || course.units.isEmpty) {
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

  final startIndex = _resolveUnitIndex(enrollment, course.units.length);

  // The local window cache is used only to pick which unit to resume with
  // inside the same, still-open window (skip units already done this
  // window) — never to decide whether the cap itself has been reached.
  // That decision belongs to the server alone.
  var nextUnitIndex = startIndex;
  while (nextUnitIndex < course.units.length) {
    final unitKey = course.units[nextUnitIndex].name;
    final alreadyDoneThisWindow = sessionWindowRepository.hasCompletedUnitThisWindow(
      activeProfile.learnerId,
      unitKey,
      learnerState.windowStartDate,
    );
    if (!alreadyDoneThisWindow) break;
    nextUnitIndex++;
  }

  if (nextUnitIndex >= course.units.length) {
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
    unit: course.units[nextUnitIndex],
    unitIndex: nextUnitIndex,
    weeklyCapAlreadyReached: false,
  );
});
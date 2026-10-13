import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapapp/chat/chat.dart' hide SubmissionAnswer;
import 'package:tapapp/chat/submission/submission.dart';
import 'package:tapapp/core/course/course.dart';
import 'package:tapapp/core/flow/flow.dart';
import 'package:tapapp/core/learner/learner.dart';
import 'package:tapapp/core/localization/language.dart';
import 'package:tapapp/core/network/network.dart';
import 'package:tapapp/core/profile/profile.dart';
import 'package:tapapp/core/providers.dart';
import 'package:tapapp/core/storage/storage.dart';
import 'package:tapapp/features/home/home.dart';

export 'package:tapapp/chat/submission/submission.dart' show SubmissionAnswer;

enum ClassroomProgressStage {
  watchVideo,
  submitProject,
  takeQuiz,
  unitCompleted;

  double get revealProgress => switch (this) {
    ClassroomProgressStage.watchVideo => 0,
    ClassroomProgressStage.submitProject => 0.34,
    ClassroomProgressStage.takeQuiz => 0.67,
    ClassroomProgressStage.unitCompleted => 1,
  };
}

class ClassroomProgressSnapshot {
  const ClassroomProgressSnapshot({
    required this.stage,
    required this.videoDone,
    required this.submissionDone,
    required this.quizDone,
  });

  final ClassroomProgressStage stage;
  final bool videoDone;
  final bool submissionDone;
  final bool quizDone;
}

class ClassroomProgressResolver {
  const ClassroomProgressResolver._();

  static int resolveUnitIndexForCourse(
    EnrollmentModel enrollment,
    List<CourseUnitModel> units,
  ) {
    if (units.isEmpty) return 0;
    for (var index = 0; index < units.length; index++) {
      final snapshot = resolve(
        enrollment: enrollment,
        unitIndex: index,
        unit: units[index],
      );
      if (snapshot.stage != ClassroomProgressStage.unitCompleted) {
        return index;
      }
    }
    return units.length - 1;
  }

  static ClassroomProgressSnapshot resolve({
    required EnrollmentModel enrollment,
    required int unitIndex,
    CourseUnitModel? unit,
  }) {
    final videoDone = enrollment.videosCompleted > unitIndex;
    final submissionDone = enrollment.submissionIndex > unitIndex;
    final quizDone = enrollment.quizzesCompleted > unitIndex;
    final hasSubmission = unit == null || unit.assignments.isNotEmpty;
    final hasQuiz = unit == null || (unit.quiz?.questions.isNotEmpty ?? true);

    final stage = !videoDone
        ? ClassroomProgressStage.watchVideo
        : hasSubmission && !submissionDone
        ? ClassroomProgressStage.submitProject
        : hasQuiz && !quizDone
        ? ClassroomProgressStage.takeQuiz
        : ClassroomProgressStage.unitCompleted;

    return ClassroomProgressSnapshot(
      stage: stage,
      videoDone: videoDone,
      submissionDone: !hasSubmission || submissionDone,
      quizDone: !hasQuiz || quizDone,
    );
  }
}

class ClassSessionWindowModel {
  const ClassSessionWindowModel({
    required this.learnerId,
    required this.completedUnitKeysThisWindow,
    this.windowResetsOn,
    this.windowStartDate,
  });

  final String learnerId;
  final List<String> completedUnitKeysThisWindow;
  final String? windowResetsOn;
  final String? windowStartDate;

  factory ClassSessionWindowModel.fromJson(Map<String, dynamic> json) =>
      ClassSessionWindowModel(
        learnerId: json['learner_id'] as String? ?? '',
        completedUnitKeysThisWindow:
            (json['completed_unit_keys'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        windowResetsOn: json['window_resets_on'] as String?,
        windowStartDate: json['window_start_date'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'learner_id': learnerId,
    'completed_unit_keys': completedUnitKeysThisWindow,
    'window_resets_on': windowResetsOn,
    'window_start_date': windowStartDate,
  };

  bool coversWindow(String? currentWindowStartDate) {
    if (windowStartDate == null || currentWindowStartDate == null) return false;
    return windowStartDate == currentWindowStartDate;
  }

  ClassSessionWindowModel withUnitCompleted(
    String unitKey, {
    String? windowResetsOn,
    String? windowStartDate,
  }) => ClassSessionWindowModel(
    learnerId: learnerId,
    completedUnitKeysThisWindow: [
      ...completedUnitKeysThisWindow,
      if (!completedUnitKeysThisWindow.contains(unitKey)) unitKey,
    ],
    windowResetsOn: windowResetsOn ?? this.windowResetsOn,
    windowStartDate: windowStartDate ?? this.windowStartDate,
  );

  static ClassSessionWindowModel empty(String learnerId) =>
      ClassSessionWindowModel(
        learnerId: learnerId,
        completedUnitKeysThisWindow: const [],
      );
}

class SubmissionReviewModel {
  const SubmissionReviewModel({
    required this.score,
    this.verdict,
    required this.feedback,
    this.smsText,
    required this.strengths,
    required this.improvements,
  });

  final int score;
  final String? verdict;
  final String feedback;
  final String? smsText;
  final List<String> strengths;
  final List<String> improvements;

  bool get passed => verdict == 'pass';

  factory SubmissionReviewModel.fromJson(Map<String, dynamic> json) =>
      SubmissionReviewModel(
        score: (json['score'] as num?)?.toInt() ?? 0,
        verdict: json['verdict'] as String?,
        feedback: json['feedback'] as String? ?? '',
        smsText: json['sms_text'] as String?,
        strengths:
            (json['strengths'] as List?)?.whereType<String>().toList() ??
            const [],
        improvements:
            (json['improvements'] as List?)?.whereType<String>().toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
    'score': score,
    'verdict': verdict,
    'feedback': feedback,
    'sms_text': smsText,
    'strengths': strengths,
    'improvements': improvements,
  };
}

class ArchetypeStepSelector {
  ArchetypeStepSelector._();

  static CourseAssignmentModel? selectAssignment(
    List<CourseAssignmentModel> assignments,
    String archetype,
  ) {
    if (assignments.isEmpty) return null;

    final normalized = LearnerArchetype.normalize(archetype);
    for (final assignment in assignments) {
      if (assignment.id.toLowerCase().contains(normalized)) {
        return assignment;
      }
    }
    return assignments.first;
  }

  static CourseAssignmentStepModel? selectStep(
    List<CourseAssignmentStepModel> steps,
    String archetype,
  ) {
    if (steps.isEmpty) return null;

    final normalized = LearnerArchetype.normalize(archetype);
    final preferredKinds = switch (normalized) {
      LearnerArchetype.dormant => const ['emoji'],
      LearnerArchetype.fenceSitter => const ['text,audio', 'audio', 'text'],
      LearnerArchetype.irregularSubmitter => const ['image'],
      LearnerArchetype.submitter => const ['image,video', 'video'],
      _ => const ['emoji'],
    };

    for (final preferred in preferredKinds) {
      for (final step in steps) {
        if (_normalizeSubTypes(step.subTypes) == preferred) return step;
      }
    }
    debugPrint(
      'ArchetypeStepSelector: no step matched archetype "$normalized" for '
      'assignment steps with sub_types ${steps.map((s) => s.subTypes).toList()}; '
      'falling back to steps.first',
    );
    return steps.first;
  }

  static String _normalizeSubTypes(String value) => value
      .split(',')
      .map((part) => part.trim().toLowerCase())
      .where((part) => part.isNotEmpty)
      .join(',');
}

class ClassSessionWindowRepository {
  ClassSessionWindowRepository(this._localCache);

  final LocalCache _localCache;

  ClassSessionWindowModel read(String learnerId) {
    final raw = _localCache.getForeverRaw(
      CacheKeys.classSessionWindow(learnerId),
    );
    if (raw == null) return ClassSessionWindowModel.empty(learnerId);
    return ClassSessionWindowModel.fromJson(raw);
  }

  bool isStale(String learnerId, String? currentWindowStartDate) =>
      !read(learnerId).coversWindow(_windowStart(currentWindowStartDate));

  bool hasCompletedUnitThisWindow(
    String learnerId,
    String unitKey,
    String? currentWindowStartDate,
  ) {
    if (isStale(learnerId, currentWindowStartDate)) return false;
    return read(learnerId).completedUnitKeysThisWindow.contains(unitKey);
  }

  int completedUnitCountThisWindow(
    String learnerId,
    String? currentWindowStartDate,
  ) {
    if (isStale(learnerId, currentWindowStartDate)) return 0;
    return read(learnerId).completedUnitKeysThisWindow.length;
  }

  Future<void> markUnitCompleted({
    required String learnerId,
    required String unitKey,
    String? windowResetsOn,
    String? windowStartDate,
  }) async {
    final existing = read(learnerId);
    final effectiveWindowStart = _windowStart(windowStartDate);
    final sameWindow = existing.coversWindow(effectiveWindowStart);
    final base = sameWindow
        ? existing
        : ClassSessionWindowModel.empty(learnerId);

    final updated = base.withUnitCompleted(
      unitKey,
      windowResetsOn: windowResetsOn,
      windowStartDate: effectiveWindowStart,
    );

    await _localCache.setForeverRaw(
      CacheKeys.classSessionWindow(learnerId),
      updated.toJson(),
    );
  }

  Future<void> reset(String learnerId) async {
    await _localCache.delete(CacheKeys.classSessionWindow(learnerId));
  }

  String _windowStart(String? serverWindowStart) {
    if (serverWindowStart != null && serverWindowStart.isNotEmpty) {
      return serverWindowStart;
    }
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }
}

class SubmissionReviewRepository {
  SubmissionReviewRepository(this._http, this._localCache);

  final HttpClient _http;
  final LocalCache _localCache;

  static const Duration _cacheTtl = Duration(hours: 24);

  Future<Map<String, dynamic>> reviewSubmission({
    required String phone,
    required String learnerId,
    required String assignmentId,
    required String stepId,
    required String submissionText,
    String? question,
    String? expectedAnswer,
    String? rubric,
  }) async {
    final key = CacheKeys.submissionReview(learnerId, assignmentId, stepId);

    final cachedAt = _localCache.cachedAt(key);
    final cachedRaw = _localCache.getForeverRaw(key);
    final isFresh =
        cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl;
    if (cachedRaw != null && isFresh) {
      return {
        'success': true,
        'learner_id': learnerId,
        'review': cachedRaw,
        'from_cache': true,
      };
    }

    final data = await _http.post(
      ApiEndpoints.submissionReview,
      body: {
        'phone': phone,
        'learner_id': learnerId,
        'submission_text': submissionText,
        'question': ?question,
        'expected_answer': ?expectedAnswer,
        'rubric': ?rubric,
      },
    );

    final review = data['review'];
    if (data['success'] == true && review is Map) {
      final model = SubmissionReviewModel.fromJson(
        Map<String, dynamic>.from(review),
      );
      await _localCache.setForeverRaw(key, model.toJson());
    }
    return data;
  }
}

final submissionReviewRepositoryProvider =
    FutureProvider<SubmissionReviewRepository>((ref) async {
      final localCache = await ref.watch(localCacheProvider.future);
      return SubmissionReviewRepository(
        ref.watch(httpClientProvider),
        localCache,
      );
    });

final activityFlowProvider = FutureProvider.autoDispose
    .family<Map<String, FlowNode>, String>((ref, languageCode) async {
      final resolved = await ref.watch(
        resolvedFlowProvider((
          category: 'activity',
          fileName: 'activity_flow.json',
          languageCode: languageCode,
        )).future,
      );
      return FlowResolver.parse(resolved.data).steps;
    });

class NoActiveProfileException implements Exception {
  const NoActiveProfileException();

  @override
  String toString() => 'No active profile is selected.';
}

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
      final resolution = await ClassroomSessionResolver.resolve(ref);

      return ClassSessionBootstrap(
        learnerId: resolution.learnerState.learnerId,
        phone: resolution.phone,
        learnerState: resolution.learnerState,
        courseName: resolution.course?.name ?? '',
        unit: resolution.unit,
        nextUnit: resolution.nextUnit,
        unitIndex: resolution.unitIndex,
        weeklyCapAlreadyReached: resolution.weeklyCapReached,
      );
    });

class ClassroomSessionResolution {
  const ClassroomSessionResolution({
    required this.phone,
    required this.learnerState,
    required this.course,
    required this.unit,
    required this.nextUnit,
    required this.unitIndex,
    required this.weeklyCapReached,
    required this.showCompletionCelebration,
    required this.completionPoints,
  });

  final String phone;
  final LearnerStateModel learnerState;
  final CourseDetailModel? course;
  final CourseUnitModel? unit;
  final CourseUnitModel? nextUnit;
  final int unitIndex;
  final bool weeklyCapReached;
  final bool showCompletionCelebration;
  final int completionPoints;
}

class ClassroomSessionResolver {
  ClassroomSessionResolver._();

  static Future<ClassroomSessionResolution> resolve(
    Ref ref, {
    bool forceRefresh = false,
  }) async {
    final activeProfile = await ref.watch(activeProfileProvider.future);
    if (activeProfile == null) {
      throw const NoActiveProfileException();
    }

    final learnerStateRepository = await ref.watch(
      learnerStateRepositoryProvider.future,
    );

    var learnerState = await learnerStateRepository.fetchState(
      learnerId: activeProfile.learnerId,
      forceRefresh: forceRefresh,
    );

    final sessionWindowRepository = await ref.watch(
      classSessionWindowRepositoryProvider.future,
    );

    if (sessionWindowRepository.isStale(
      activeProfile.learnerId,
      learnerState.windowStartDate,
    )) {
      learnerState = await learnerStateRepository.fetchState(
        learnerId: activeProfile.learnerId,
        forceRefresh: true,
      );
    }

    if (!learnerState.hasReachedWeeklyActivityLimit() &&
        learnerState.hasPendingLocalProgress) {
      final synced = await learnerStateRepository.syncCompletedLocalProgress(
        activeProfile.learnerId,
      );
      if (synced != null) learnerState = synced;
    }

    final localCompleted = sessionWindowRepository.completedUnitCountThisWindow(
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

    final weeklyCapReached = learnerState.hasReachedWeeklyActivityLimit(
      localCompleted: localCompleted,
    );

    if (course == null || course.units.isEmpty) {
      return ClassroomSessionResolution(
        phone: activeProfile.phone,
        learnerState: learnerState,
        course: course,
        unit: null,
        nextUnit: null,
        unitIndex: 0,
        weeklyCapReached: true,
        showCompletionCelebration: false,
        completionPoints: 0,
      );
    }

    final unitIndex = ClassroomProgressResolver.resolveUnitIndexForCourse(
      enrollment,
      course.units,
    );
    final selectedUnit = course.units[unitIndex];
    final nextUnit = unitIndex + 1 < course.units.length
        ? course.units[unitIndex + 1]
        : null;

    var progress = ClassroomProgressResolver.resolve(
      enrollment: enrollment,
      unitIndex: unitIndex,
      unit: selectedUnit,
    );

    if (!learnerState.hasPendingLocalProgress &&
        progress.stage != ClassroomProgressStage.watchVideo &&
        progress.stage != ClassroomProgressStage.unitCompleted) {
      learnerState = await learnerStateRepository.prepareLocalUnit(
        learnerId: activeProfile.learnerId,
        unitIndex: unitIndex,
      );
      enrollment = learnerState.enrollment!;
      progress = ClassroomProgressResolver.resolve(
        enrollment: enrollment,
        unitIndex: unitIndex,
        unit: selectedUnit,
      );
    }

    final allUnitsDone =
        unitIndex >= course.units.length - 1 &&
        progress.videoDone &&
        progress.submissionDone &&
        progress.quizDone;

    if (allUnitsDone) {
      return ClassroomSessionResolution(
        phone: activeProfile.phone,
        learnerState: learnerState,
        course: course,
        unit: null,
        nextUnit: nextUnit,
        unitIndex: unitIndex,
        weeklyCapReached: weeklyCapReached,
        showCompletionCelebration: false,
        completionPoints: 0,
      );
    }

    if (weeklyCapReached &&
        progress.stage == ClassroomProgressStage.watchVideo) {
      return ClassroomSessionResolution(
        phone: activeProfile.phone,
        learnerState: learnerState,
        course: course,
        unit: null,
        nextUnit: nextUnit,
        unitIndex: unitIndex,
        weeklyCapReached: true,
        showCompletionCelebration: false,
        completionPoints: 0,
      );
    }

    if (progress.stage == ClassroomProgressStage.unitCompleted) {
      if (weeklyCapReached) {
        return ClassroomSessionResolution(
          phone: activeProfile.phone,
          learnerState: learnerState,
          course: course,
          unit: null,
          nextUnit: nextUnit,
          unitIndex: unitIndex,
          weeklyCapReached: true,
          showCompletionCelebration: false,
          completionPoints: 0,
        );
      }

      final celebration = learnerStateRepository.readHomeCelebration(
        activeProfile.learnerId,
      );
      return ClassroomSessionResolution(
        phone: activeProfile.phone,
        learnerState: learnerState,
        course: course,
        unit: selectedUnit,
        nextUnit: nextUnit,
        unitIndex: unitIndex,
        weeklyCapReached: false,
        showCompletionCelebration: celebration?['show'] == true,
        completionPoints: (celebration?['points'] as num?)?.toInt() ?? 0,
      );
    }

    return ClassroomSessionResolution(
      phone: activeProfile.phone,
      learnerState: learnerState,
      course: course,
      unit: selectedUnit,
      nextUnit: nextUnit,
      unitIndex: unitIndex,
      weeklyCapReached: false,
      showCompletionCelebration: false,
      completionPoints: 0,
    );
  }
}

const int kClassroomQuizPointsPerCorrectAnswer = 5;

enum ClassSessionOutcome { choice, weeklyCapReached }

const String _saveFailedVideo =
    'We could not save that you watched the video. Please check your connection and retry.';
const String _saveFailedSubmission =
    'We could not save your completed submission. Please check your connection and retry.';
const String _saveFailedQuiz =
    'We could not save your quiz result. Please check your connection and retry.';
const String _saveFailedFinish =
    'We could not save your progress. Please check your connection.';
const String _unknownFinish = 'Something went wrong saving your progress.';
const String _pendingReviewText =
    'Got it! Your submission is in — great work.';

class ClassroomChatActionHandler extends ChangeNotifier
    implements ChatActionHandler {
  ClassroomChatActionHandler({
    required this.learnerId,
    required this.phone,
    required this.studentName,
    required this.unit,
    required this.nextUnit,
    required this.unitIndex,
    required LearnerStateModel initialLearnerState,
    required LearnerStateRepository learnerStateRepository,
    required SubmissionReviewRepository submissionReviewRepository,
    required ClassSessionWindowRepository sessionWindowRepository,
    this.onProgressSaved,
  }) : _learnerState = initialLearnerState,
       _startingPoints = initialLearnerState.xp ?? 0,
       _learnerStateRepository = learnerStateRepository,
       _submissionReviewRepository = submissionReviewRepository,
       _sessionWindowRepository = sessionWindowRepository;

  final String learnerId;
  final String phone;
  final String studentName;
  final CourseUnitModel unit;
  final CourseUnitModel? nextUnit;
  final int unitIndex;
  final VoidCallback? onProgressSaved;

  final LearnerStateRepository _learnerStateRepository;
  final SubmissionReviewRepository _submissionReviewRepository;
  final ClassSessionWindowRepository _sessionWindowRepository;
  final int _startingPoints;

  LearnerStateModel _learnerState;
  bool _videoWatched = false;
  bool _submissionAccepted = false;
  bool _quizSaved = false;
  bool _completing = false;
  int _videoPoints = 0;
  int _submissionPoints = 0;
  int _quizPoints = 0;
  int _completedUnitPoints = 0;
  ClassSessionOutcome? _outcome;
  Future<ChatActionResult> Function()? _pendingRetry;

  LearnerStateModel get learnerState => _learnerState;
  ClassSessionOutcome? get outcome => _outcome;
  int get startingPoints => _startingPoints;
  int get sessionTotalPoints => _videoPoints + _submissionPoints + _quizPoints;
  int get displayedTotalPoints => _startingPoints + sessionTotalPoints;
  String get unitName => unit.name;

  ClassroomProgressStage get currentProgressStage {
    if (!_videoWatched) return ClassroomProgressStage.watchVideo;
    if (!_submissionAccepted) return ClassroomProgressStage.submitProject;
    if (!_quizSaved) return ClassroomProgressStage.takeQuiz;
    return ClassroomProgressStage.unitCompleted;
  }

  double get revealProgress => currentProgressStage.revealProgress;

  String get _archetype => LearnerArchetype.normalize(_learnerState.archetype);

  CourseVideoModel? get _video =>
      unit.videos.isNotEmpty ? unit.videos.first : null;

  CourseAssignmentModel? get _assignment =>
      ArchetypeStepSelector.selectAssignment(unit.assignments, _archetype);

  bool get _submissionNotRequired {
    final assignment = _assignment;
    return assignment == null || assignment.steps.isEmpty;
  }

  bool get _quizNotRequired => unit.quiz == null || unit.quiz!.questions.isEmpty;

  bool get _requiredStagesDone =>
      _videoWatched &&
      (_submissionNotRequired || _submissionAccepted) &&
      (_quizNotRequired || _quizSaved);

  Future<void> initialize(ClassroomProgressSnapshot progress) async {
    _videoWatched = progress.videoDone;
    _submissionAccepted = progress.submissionDone;
    _quizSaved = progress.quizDone;

    if (progress.stage != ClassroomProgressStage.unitCompleted) return;

    if (_learnerState.hasPendingLocalProgress) {
      await _finishUnit();
      return;
    }
    _outcome = _stateSaysCapped(_learnerState)
        ? ClassSessionOutcome.weeklyCapReached
        : ClassSessionOutcome.choice;
    notifyListeners();
  }

  void recordQuizFeedback(ChatQuizFeedback feedback) {
    if (!feedback.isCorrect) return;
    _quizPoints += feedback.points;
  }

  @override
  Future<ChatActionResult> handle(
    ChatAction action, {
    Map<String, Object?>? data,
  }) {
    switch (action) {
      case ChatAction.watchVideo:
        return _watchVideo();
      case ChatAction.submitAnswer:
        return _submitAnswer(data);
      case ChatAction.continueFlow:
        return _continueFlow(data);
      case ChatAction.retrySave:
      case ChatAction.retrySubmission:
        return _retryPending();
      case ChatAction.finishUnit:
        return _finishUnit();
      case ChatAction.startQuiz:
      case ChatAction.watchAnother:
      case ChatAction.maybeLater:
      case ChatAction.openHome:
      case ChatAction.editProfile:
      case ChatAction.enrollCourse:
      case ChatAction.saveProfile:
      case ChatAction.completeOnboarding:
      case ChatAction.aiCall:
      case ChatAction.submitFreeText:
        return Future.value(ChatActionResult.ok());
    }
  }

  Future<ChatActionResult> _watchVideo() async {
    final video = _video;
    if (_videoWatched || video == null) return ChatActionResult.ok();
    return _persist(
      write: () => _learnerStateRepository.cacheLocalProgress(
        learnerId: learnerId,
        xp: video.points,
        videoIndex: unitIndex + 1,
      ),
      failureMessage: _saveFailedVideo,
      onSaved: () {
        _videoWatched = true;
        _videoPoints += video.points;
      },
      payload: {'points': video.points},
    );
  }

  Future<ChatActionResult> _submitAnswer(Map<String, Object?>? data) async {
    final answer = _answerFrom(data?['answer']);
    if (answer == null) {
      return ChatActionResult.failure('Could not read your answer. Please try again.');
    }

    final assignment = _assignment;
    final step = assignment == null
        ? null
        : ArchetypeStepSelector.selectStep(assignment.steps, _archetype);

    if (assignment == null || step == null) {
      return _recordSubmission({
        'text': '',
        'passed': true,
        'is_final_step': true,
      });
    }

    final isMedia =
        answer.kind == SubmissionKind.image ||
        answer.kind == SubmissionKind.video ||
        answer.kind == SubmissionKind.imageVideo;

    if (isMedia) {
      return _recordSubmission({
        'text': _pendingReviewText,
        'passed': true,
        'is_final_step': true,
      });
    }

    final needsAiReview = SubmissionKindResolver.requiresAiReview(answer.kind);

    if (!needsAiReview) {
      final passed = answer.matchesCriteria(step.validCriteria);
      return _recordSubmission({
        'text': passed
            ? _praise()
            : "That's a good try — let's keep practicing this one.",
        'passed': passed,
        'is_final_step': passed,
      });
    }

    try {
      final response = await _submissionReviewRepository.reviewSubmission(
        phone: phone,
        learnerId: learnerId,
        assignmentId: assignment.id,
        stepId: step.step.toString(),
        submissionText: answer.text ?? step.unguidedText,
        question: assignment.description,
        expectedAnswer: step.validCriteria,
        rubric: null,
      );
      final reviewRaw = response['review'];
      final review = reviewRaw is Map
          ? Map<String, dynamic>.from(reviewRaw)
          : const <String, dynamic>{};
      final passed = response['success'] == true && review['verdict'] == 'pass';
      final feedback = review['feedback'] as String?;

      return _recordSubmission({
        'text': passed
            ? _praise()
            : (feedback ??
                  "That submission didn't quite pass this time — let's try again."),
        'passed': passed,
        'is_final_step': passed,
        'score': (review['score'] as num?)?.toInt(),
        'feedback': feedback,
        'strengths': review['strengths'],
        'improvements': review['improvements'],
        'sms_text': review['sms_text'],
      });
    } catch (_) {
      return _recordSubmission({
        'text': "That submission didn't quite pass this time — let's try again.",
        'passed': false,
        'is_final_step': false,
      });
    }
  }

  Future<ChatActionResult> _recordSubmission(Map<String, Object?> payload) {
    if (payload['passed'] != true) {
      return Future.value(ChatActionResult.ok(payload: payload));
    }
    return _persist(
      write: () => _learnerStateRepository.cacheLocalProgress(
        learnerId: learnerId,
        xp: unit.xp,
        submissionIndex: unitIndex + 1,
      ),
      failureMessage: _saveFailedSubmission,
      onSaved: () {
        _submissionAccepted = true;
        _submissionPoints += unit.xp;
      },
      payload: payload,
    );
  }

  Future<ChatActionResult> _continueFlow(Map<String, Object?>? data) {
    final checkpoint = data?['checkpointAction'] as String?;
    if (checkpoint == null) return _retryPending();
    switch (checkpoint) {
      case 'totals':
        return _saveQuiz();
      case 'finish':
        return _finishUnit();
      default:
        return Future.value(ChatActionResult.ok());
    }
  }

  Future<ChatActionResult> _retryPending() async {
    final retry = _pendingRetry;
    if (retry == null) return ChatActionResult.ok();
    _pendingRetry = null;
    return retry();
  }

  Future<ChatActionResult> _saveQuiz() async {
    if (_quizSaved) return ChatActionResult.ok();
    final result = await _persist(
      write: () => _learnerStateRepository.cacheLocalProgress(
        learnerId: learnerId,
        xp: _quizPoints,
        quizIndex: unitIndex + 1,
      ),
      failureMessage: _saveFailedQuiz,
      onSaved: () {
        _quizSaved = true;
      },
    );
    if (!result.success) _pendingRetry = _saveQuiz;
    return result;
  }

  Future<ChatActionResult> _finishUnit() async {
    if (_outcome != null) {
      return ChatActionResult.ok(payload: {'outcome': _outcome!.name});
    }
    if (_completing) return ChatActionResult.ok();
    if (!_requiredStagesDone) {
      return ChatActionResult.failure('Finish the activity steps first.');
    }

    _completing = true;
    final unitKey = unit.name;
    try {
      await _learnerStateRepository.markLocalProgressReady(learnerId);
      _completedUnitPoints = _learnerState.pendingProgressXp > 0
          ? _learnerState.pendingProgressXp
          : sessionTotalPoints;

      final submitted = await _learnerStateRepository.submitProgress(
        learnerId: learnerId,
        xp: _completedUnitPoints > 0 ? _completedUnitPoints : null,
        activityType: 'unit_complete',
        videoIndex: _videoWatched ? unitIndex + 1 : null,
        quizIndex: _quizSaved ? unitIndex + 1 : null,
        submissionIndex: _submissionAccepted ? unitIndex + 1 : null,
        fields: completedUnitStateFields,
      );

      _learnerState = _reconcileArchetype(submitted);
      await _markWindowCompleted(unitKey);
      _outcome = await _completionOutcome();
      _pendingRetry = null;
      onProgressSaved?.call();
      notifyListeners();
      return ChatActionResult.ok(payload: {'outcome': _outcome!.name});
    } on ProgressConflictException {
      return _recoverFromConflict(unitKey);
    } catch (_) {
      if (_stateSaysCapped(_learnerState) &&
          _learnerState.hasPendingLocalProgress) {
        await _learnerStateRepository.clearHomeCelebration(learnerId);
        _outcome = ClassSessionOutcome.weeklyCapReached;
        notifyListeners();
        return ChatActionResult.ok(payload: {'outcome': _outcome!.name});
      }
      _pendingRetry = _finishUnit;
      return ChatActionResult.failure(_unknownFinish);
    } finally {
      _completing = false;
    }
  }

  Future<ChatActionResult> _recoverFromConflict(String unitKey) async {
    try {
      _learnerState = await _learnerStateRepository.fetchState(
        learnerId: learnerId,
        forceRefresh: true,
      );
      await _markWindowCompleted(unitKey);
      _outcome = await _completionOutcome();
      onProgressSaved?.call();
      notifyListeners();
      return ChatActionResult.ok(payload: {'outcome': _outcome!.name});
    } catch (_) {
      _pendingRetry = _finishUnit;
      return ChatActionResult.failure(_saveFailedFinish);
    }
  }

  Future<ChatActionResult> _persist({
    required Future<LearnerStateModel> Function() write,
    required String failureMessage,
    required void Function() onSaved,
    Map<String, Object?>? payload,
  }) async {
    try {
      _learnerState = await write();
    } catch (_) {
      return ChatActionResult.failure(failureMessage);
    }
    onSaved();
    onProgressSaved?.call();
    notifyListeners();
    return ChatActionResult.ok(payload: payload);
  }

  Future<void> _markWindowCompleted(String unitKey) =>
      _sessionWindowRepository.markUnitCompleted(
        learnerId: learnerId,
        unitKey: unitKey,
        windowResetsOn: _learnerState.windowResetsOn,
        windowStartDate: _learnerState.windowStartDate,
      );

  bool _stateSaysCapped(LearnerStateModel state, {int localCompleted = 0}) =>
      state.hasReachedWeeklyActivityLimit(localCompleted: localCompleted);

  Future<ClassSessionOutcome> _completionOutcome() async {
    final localCompleted = _sessionWindowRepository.completedUnitCountThisWindow(
      learnerId,
      _learnerState.windowStartDate,
    );
    if (_stateSaysCapped(_learnerState, localCompleted: localCompleted)) {
      await _learnerStateRepository.clearHomeCelebration(learnerId);
      return ClassSessionOutcome.weeklyCapReached;
    }
    await _learnerStateRepository.showHomeCelebration(
      learnerId,
      points: _completedUnitPoints,
    );
    return ClassSessionOutcome.choice;
  }

  LearnerStateModel _reconcileArchetype(LearnerStateModel serverState) {
    if (serverState.archetype != null && serverState.archetype!.isNotEmpty) {
      return serverState;
    }
    serverState.archetype = LocalArchetypeCalculator.compute(
      streak: serverState.streak ?? 0,
      submissionCount: serverState.submissionIndex ?? 0,
      lastActivityDate: serverState.lastActivityDate,
      now: DateTime.now(),
    );
    return serverState;
  }

  SubmissionAnswer? _answerFrom(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind']?.toString();
    final text = raw['text'] as String?;
    final emoji = raw['emoji'] as String?;
    final path = raw['mediaPath'] as String?;

    switch (kind) {
      case 'emoji':
        return emoji == null ? null : SubmissionAnswer.emoji(emoji);
      case 'text':
        return text == null ? null : SubmissionAnswer.text(text);
      case 'textAudio':
      case 'audio':
        return text == null ? null : SubmissionAnswer.audioTranscript(text);
      case 'image':
        return path == null ? null : SubmissionAnswer.image(path);
      case 'video':
        return path == null ? null : SubmissionAnswer.video(path);
      case 'imageVideo':
        return path == null
            ? null
            : SubmissionAnswer.imageOrVideo(path, isVideo: raw['isVideo'] == true);
      default:
        return null;
    }
  }

  String _praise() => "I am SO proud of you $studentName 🥹 That's the spirit!";
}

class ClassroomChatContentSource implements ChatContentSource {
  ClassroomChatContentSource({required this.unit, required this.handler});

  final CourseUnitModel unit;
  final ClassroomChatActionHandler handler;

  @override
  Set<ChatItemKind> get boundKinds => const {
    ChatItemKind.video,
    ChatItemKind.submission,
    ChatItemKind.quiz,
  };

  @override
  Future<ChatItem?> bind(FlowNode node, ChatBindContext ctx) async =>
      switch (ChatItemBuilder.kindFor(node)) {
        ChatItemKind.video => _video(node, ctx),
        ChatItemKind.submission => _submission(node, ctx),
        ChatItemKind.quiz => _quiz(node, ctx),
        _ => null,
      };

  ChatItem? _video(FlowNode node, ChatBindContext ctx) {
    if (unit.videos.isEmpty) return null;
    return ContentResolver.video(
      unit.videos.first,
      id: ctx.id,
      stepId: node.stepId,
    );
  }

  ChatItem? _submission(FlowNode node, ChatBindContext ctx) {
    final archetype = LearnerArchetype.normalize(
      handler.learnerState.archetype,
    );
    final assignment = ArchetypeStepSelector.selectAssignment(
      unit.assignments,
      archetype,
    );
    if (assignment == null) return null;
    final step = ArchetypeStepSelector.selectStep(assignment.steps, archetype);
    if (step == null) return null;
    return ContentResolver.submissionStep(
      assignment,
      step,
      id: ctx.id,
      stepId: node.stepId,
      points: unit.xp,
      stepNumber: step.step,
      stepTotal: 0,
    );
  }

  ChatItem? _quiz(FlowNode node, ChatBindContext ctx) {
    final questions = ContentResolver.quizQuestions(
      unit.quiz,
      idPrefix: ctx.id,
      stepId: node.stepId,
    );
    ctx.variables['quizTotal'] = questions.length;
    final index = ctx.variables.quizIndex;
    if (index < 0 || index >= questions.length) return null;
    return questions[index];
  }
}

class NoUnitAvailableException implements Exception {
  const NoUnitAvailableException();

  @override
  String toString() => 'No unit is available to run right now.';
}

class ClassroomChatDeps {
  const ClassroomChatDeps({
    required this.key,
    required this.handler,
    required this.templateContext,
    required this.contentSource,
    required this.learnerId,
    required this.studentName,
    required this.courseDisplay,
    required this.unit,
    required this.nextUnit,
    required this.unitIndex,
  });

  final ChatSessionKey key;
  final ClassroomChatActionHandler handler;
  final TemplateContext templateContext;
  final ClassroomChatContentSource contentSource;
  final String learnerId;
  final String studentName;
  final String courseDisplay;
  final CourseUnitModel unit;
  final CourseUnitModel? nextUnit;
  final int unitIndex;
}

String _entryStepFor(ClassroomProgressStage stage) => switch (stage) {
  ClassroomProgressStage.watchVideo => 'AF-001',
  ClassroomProgressStage.submitProject => 'AF-006',
  ClassroomProgressStage.takeQuiz => 'AF-QUIZ-QUESTION',
  ClassroomProgressStage.unitCompleted => 'AF-011',
};

final classroomChatDepsProvider = FutureProvider.autoDispose
    .family<ClassroomChatDeps, int>((ref, attempt) async {
      final bootstrap = await ref.watch(classSessionBootstrapProvider.future);
      final unit = bootstrap.unit;
      if (unit == null) throw const NoUnitAvailableException();

      final languageCode = ref.watch(languageProvider);
      final learnerStateRepository = await ref.watch(
        learnerStateRepositoryProvider.future,
      );
      final submissionReviewRepository = await ref.watch(
        submissionReviewRepositoryProvider.future,
      );
      final sessionWindowRepository = await ref.watch(
        classSessionWindowRepositoryProvider.future,
      );

      final studentName =
          bootstrap.learnerState.profile?.studentName ?? 'Champ';
      var providerIsActive = true;

      final handler = ClassroomChatActionHandler(
        learnerId: bootstrap.learnerId,
        phone: bootstrap.phone,
        studentName: studentName,
        unit: unit,
        nextUnit: bootstrap.nextUnit,
        unitIndex: bootstrap.unitIndex,
        initialLearnerState: bootstrap.learnerState,
        learnerStateRepository: learnerStateRepository,
        submissionReviewRepository: submissionReviewRepository,
        sessionWindowRepository: sessionWindowRepository,
        onProgressSaved: () {
          if (!providerIsActive) return;
          ref.invalidate(learnerStateDataProvider(bootstrap.learnerId));
          ref.invalidate(learningDashboardProvider);
        },
      );

      ref.onDispose(() {
        providerIsActive = false;
        handler.dispose();
      });

      final contentSource = ClassroomChatContentSource(
        unit: unit,
        handler: handler,
      );

      final enrollment =
          bootstrap.learnerState.enrollment ?? const EnrollmentModel();
      final progress = ClassroomProgressResolver.resolve(
        enrollment: enrollment,
        unitIndex: bootstrap.unitIndex,
        unit: unit,
      );
      await handler.initialize(progress);

      final key = ChatSessionKey(
        profileId: bootstrap.learnerId,
        surface: 'classroom',
        category: 'activity',
        fileName: 'activity_flow.json',
        entryStepId: _entryStepFor(progress.stage),
        languageCode: languageCode,
      );

      final video = unit.videos.isNotEmpty ? unit.videos.first : null;
      final templateContext = TemplateContext(
        studentName: studentName,
        unitName: unit.name,
        courseDisplay: bootstrap.courseName,
        videoDescription: video?.description ?? unit.description,
        videoPoints: video?.points ?? 0,
        submissionPoints: unit.xp,
        quizPoints: kClassroomQuizPointsPerCorrectAnswer,
        quizQuestionCount: unit.quiz?.questions.length ?? 0,
      );

      return ClassroomChatDeps(
        key: key,
        handler: handler,
        templateContext: templateContext,
        contentSource: contentSource,
        learnerId: bootstrap.learnerId,
        studentName: studentName,
        courseDisplay: bootstrap.courseName,
        unit: unit,
        nextUnit: bootstrap.nextUnit,
        unitIndex: bootstrap.unitIndex,
      );
    });
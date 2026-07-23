import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/learner_state_model.dart';
import '../data/repositories/archetype_progression_repository.dart';
import '../data/repositories/learner_state_repository.dart';
import '../data/repositories/submission_review_repository.dart';
import '../models/activity_flow_model.dart';
import '../models/archetype_step_selector.dart';
import '../models/archetype_submission_kind.dart';
import '../models/class_chat_message_model.dart';
import '../models/learner_archetype.dart';
import '../models/local_archetype_calculator.dart';
import '../models/program_content/course_detail_model.dart';
import '../models/submission_answer_model.dart';
import 'class_session_window_repository.dart';

enum ClassSessionOutcome { none, choice, weeklyCapReached }

const int _minPassingScore = 60;
const int _quizPointsPerCorrectAnswer = 5;

class ClassChatController extends ChangeNotifier {
  ClassChatController({
    required this.learnerId,
    required this.phone,
    required this.studentName,
    required this.courseDisplay,
    required ActivityFlowModel flow,
    required CourseUnitModel unit,
    required this.unitIndex,
    required LearnerStateModel initialLearnerState,
    required LearnerStateRepository learnerStateRepository,
    required SubmissionReviewRepository submissionReviewRepository,
    required ClassSessionWindowRepository sessionWindowRepository,
    required ArchetypeProgressionRepository archetypeProgressionRepository,
  })  : _flow = flow,
        _unit = unit,
        _learnerStateRepository = learnerStateRepository,
        _submissionReviewRepository = submissionReviewRepository,
        _sessionWindowRepository = sessionWindowRepository,
        _archetypeProgressionRepository = archetypeProgressionRepository,
        _learnerState = initialLearnerState {
    _begin();
  }

  final String learnerId;
  final String phone;
  final String studentName;
  final String courseDisplay;
  final int unitIndex;

  String get unitName => _unit.name;

  final ActivityFlowModel _flow;
  final CourseUnitModel _unit;
  final LearnerStateRepository _learnerStateRepository;
  final SubmissionReviewRepository _submissionReviewRepository;
  final ClassSessionWindowRepository _sessionWindowRepository;
  final ArchetypeProgressionRepository _archetypeProgressionRepository;

  LearnerStateModel _learnerState;
  LearnerStateModel get learnerState => _learnerState;

  String get _currentArchetype => LearnerArchetype.normalize(_learnerState.archetype);

  final List<ClassChatMessage> _messages = [];
  List<ClassChatMessage> get messages => List.unmodifiable(_messages);

  bool get isAwaitingInput => _awaitingInput;
  bool _awaitingInput = false;

  bool get isAwaitingContinue => _awaitingContinue;
  bool _awaitingContinue = false;

  ClassSessionOutcome get outcome => _outcome;
  ClassSessionOutcome _outcome = ClassSessionOutcome.none;

  String? get errorMessage => _errorMessage;
  String? _errorMessage;

  int _quizIndex = 0;
  int _quizCorrectCount = 0;

  int _accumulatedVideoPoints = 0;
  int _accumulatedSubmissionPoints = 0;
  int _accumulatedQuizPoints = 0;
  bool _videoWatchedThisUnit = false;
  bool _submissionAcceptedThisUnit = false;

  CourseAssignmentStepModel? _pendingAssignmentStep;
  CourseAssignmentModel? _pendingAssignment;

  Future<Map<String, dynamic>>? _pendingReviewFuture;
  bool _submissionUsedHardcodedReply = false;

  final List<Timer> _pendingTimers = [];
  int _msgCounter = 0;

  CourseUnitModel get _currentUnit => _unit;
  CourseVideoModel? get _currentVideo {
    final vids = _currentUnit.videos;
    return vids.isNotEmpty ? vids.first : null;
  }

  CourseAssignmentModel? get _currentAssignment =>
      ArchetypeStepSelector.selectAssignment(_currentUnit.assignments, _currentArchetype);

  List<CourseQuizQuestionModel> get _quizQuestions => _currentUnit.quiz?.questions ?? const [];

  int get sessionTotalPoints =>
      _accumulatedVideoPoints + _accumulatedSubmissionPoints + _accumulatedQuizPoints;

  void _begin() {
    _runStep('AF-001');
  }

  String _interpolate(String template, {int? explicitPoints}) {
    final unit = _currentUnit;
    final hour = DateTime.now().hour;
    final partOfDay = hour < 12 ? 'morning' : (hour < 17 ? 'afternoon' : 'evening');
    return template
        .replaceAll('{{name}}', studentName)
        .replaceAll('{{part_of_day}}', partOfDay)
        .replaceAll('{{unit_name}}', unit.name)
        .replaceAll('{{course_display}}', courseDisplay)
        .replaceAll('{{video_description}}', _currentVideo?.description ?? unit.description)
        .replaceAll('{{video_points}}', '${explicitPoints ?? _currentVideo?.points ?? 0}')
        .replaceAll('{{submission_points}}', '${explicitPoints ?? unit.xp}')
        .replaceAll('{{quiz_points}}', '${explicitPoints ?? _quizPointsPerCorrectAnswer}')
        .replaceAll('{{quiz_question_count}}', '${_quizQuestions.length}');
  }

  void _runStep(String stepId) {
    final step = _flow.step(stepId);
    if (step == null) {
      _completeUnitThenReveal();
      return;
    }

    switch (stepId) {
      case 'AF-004':
        _emitVideoStep(step);
        return;
      case 'AF-007':
        _emitAssignmentStep(step);
        return;
      case 'AF-008':
        return;
      case 'AF-QUIZ-QUESTION':
        _emitQuizQuestionStep(step);
        return;
      case 'AF-011':
        _emitQuizSummaryStep(step);
        return;
    }

    if (step.isStatic) {
      _emitStaticStep(step);
    }
  }

  void _emitStaticStep(FlowStepModel step) {
    _push(ClassChatMessage(
      id: _newId(),
      stepId: step.stepId,
      sender: ClassChatSender.bot,
      contentType: ClassChatContentType.text,
      text: _interpolate(step.displayText ?? ''),
    ));
    _awaitingInput = false;

    final next = step.nextStep;
    if (next == null) {
      _scheduleAutoAdvance(step.autoAdvanceMs ?? 1100, _completeUnitThenReveal);
      return;
    }

    if (step.autoAdvanceMs != null) {
      _scheduleAutoAdvance(step.autoAdvanceMs!, () => _runStep(next));
    } else {
      _scheduleAutoAdvance(1100, () => _runStep(next));
    }
  }

  void _emitVideoStep(FlowStepModel step) {
    final video = _currentVideo;
    if (video == null) {
      _runStep(step.nextStep ?? 'AF-006');
      return;
    }
    _push(ClassChatMessage(
      id: _newId(),
      stepId: step.stepId,
      sender: ClassChatSender.bot,
      contentType: ClassChatContentType.video,
      data: {
        'videoId': video.id,
        'title': video.name,
        'description': video.description,
        'youtubeId': video.youtubeId,
        'points': video.points,
      },
    ));
    _awaitingInput = true;
    notifyListeners();
  }

  void markVideoWatched() {
    final msgIndex = _messages.lastIndexWhere((m) => m.stepId == 'AF-004' && !m.isPending);
    final video = _currentVideo;
    if (video == null) return;

    _videoWatchedThisUnit = true;
    _accumulatedVideoPoints += video.points;
    _awaitingInput = false;

    if (msgIndex != -1) {
      _messages[msgIndex] = _messages[msgIndex].copyWith(
        data: {..._messages[msgIndex].data, 'watched': true},
      );
    }

    _push(ClassChatMessage(
      id: _newId(),
      stepId: 'AF-004',
      sender: ClassChatSender.user,
      contentType: ClassChatContentType.text,
      text: 'I watched it',
    ));

    final af005 = _flow.step('AF-005');
    _push(ClassChatMessage(
      id: _newId(),
      stepId: 'AF-005',
      sender: ClassChatSender.bot,
      contentType: ClassChatContentType.text,
      text: _interpolate(af005?.displayText ?? 'Nice! +{{video_points}} points banked.',
          explicitPoints: video.points),
    ));
    _awaitingInput = false;
    _scheduleAutoAdvance(af005?.autoAdvanceMs ?? 2000, () => _runStep('AF-006'));
    notifyListeners();
  }

  void _emitAssignmentStep(FlowStepModel step) {
    final assignment = _currentAssignment;
    if (assignment == null || assignment.steps.isEmpty) {
      _submissionAcceptedThisUnit = true;
      _runStep('AF-009');
      return;
    }
    final assignStep = ArchetypeStepSelector.selectStep(assignment.steps, _currentArchetype);
    if (assignStep == null) {
      _submissionAcceptedThisUnit = true;
      _runStep('AF-009');
      return;
    }

    _pendingAssignment = assignment;
    _pendingAssignmentStep = assignStep;

    final kind = currentSubmissionKind;

    _push(ClassChatMessage(
      id: _newId(),
      stepId: step.stepId,
      sender: ClassChatSender.bot,
      contentType: ClassChatContentType.submission,
      data: {
        'assignmentName': assignment.name,
        'assignmentDesc': assignment.description,
        'unguidedText': assignStep.unguidedText,
        'guidedText': assignStep.guidedText,
        'subTypes': assignStep.subTypes,
        'submissionKind': kind.name,
        'archetype': _currentArchetype,
        'points': _currentUnit.xp,
      },
    ));
    _awaitingInput = true;
    notifyListeners();
  }

  SubmissionKind get currentSubmissionKind => ArchetypeSubmissionKind.forArchetype(_currentArchetype);

  String? _hardcodedReplyFor(SubmissionAnswer answer) {
    if (answer.kind != SubmissionKind.emoji) return null;

    switch (answer.emoji) {
      case '👍':
        return "Love that energy! Let's keep it going 🌟";
      case '👎':
        return "Thanks for being honest — we'll make the next one better!";
      case '😊':
        return "So happy to hear that! 😊";
      case '😕':
        return "No worries, learning takes practice. You're doing great!";
      case '💪':
        return "That's the spirit! You've got this 💪";
      case '🤔':
        return "Good thinking! Curiosity is how we learn.";
      default:
        return "Got it, thanks for sharing!";
    }
  }

  Future<void> submitAssignmentAnswer(SubmissionAnswer answer) async {
    final step = _pendingAssignmentStep;
    final assignment = _pendingAssignment;
    if (step == null || assignment == null || !_awaitingInput) return;

    _awaitingInput = false;

    _push(ClassChatMessage(
      id: _newId(),
      stepId: 'AF-007',
      sender: ClassChatSender.user,
      contentType: ClassChatContentType.submissionAnswerEcho,
      text: answer.displaySummary,
      data: {'kind': answer.kind.name, 'text': answer.text, 'emoji': answer.emoji},
    ));

    final needsAiReview = SubmissionKindResolver.requiresAiReview(answer.kind);
    final hardcodedReply = _hardcodedReplyFor(answer);

    if (!needsAiReview || hardcodedReply != null) {
      _submissionUsedHardcodedReply = true;
      final passed = !needsAiReview ? answer.matchesCriteria(step.validCriteria) : true;
      _push(ClassChatMessage(
        id: _newId(),
        stepId: 'AF-008',
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.submissionReview,
        text: hardcodedReply ??
            _interpolate(_flow.step('AF-008')?.displayText ?? 'Nice work! +{{submission_points}} points.'),
        data: {'passed': passed},
      ));
      await _finishAssignment(accepted: passed, awardPointsNow: passed);
      return;
    }

    _pendingReviewFuture = _submissionReviewRepository.reviewSubmission(
      phone: phone,
      learnerId: learnerId,
      submissionText: answer.text ?? step.unguidedText,
      question: assignment.description,
      expectedAnswer: step.validCriteria,
      rubric: null,
    );

    await _finishAssignment(accepted: false, awardPointsNow: false);
  }

  Future<void> _finishAssignment({required bool accepted, required bool awardPointsNow}) async {
    _submissionAcceptedThisUnit = accepted;
    if (accepted && awardPointsNow) {
      _accumulatedSubmissionPoints += _currentUnit.xp;
      final bumped = await _archetypeProgressionRepository.bumpAfterAcceptedSubmission(learnerId);
      _learnerState.archetype = bumped;
    }
    _pendingAssignment = null;
    _pendingAssignmentStep = null;
    _runStep('AF-009');
  }

  void _emitQuizQuestionStep(FlowStepModel step) {
    if (_quizIndex >= _quizQuestions.length) {
      _runStep('AF-011');
      return;
    }
    final question = _quizQuestions[_quizIndex];
    _push(ClassChatMessage(
      id: _newId(),
      stepId: step.stepId,
      sender: ClassChatSender.bot,
      contentType: ClassChatContentType.quizQuestion,
      data: {
        'questionIndex': _quizIndex,
        'totalQuestions': _quizQuestions.length,
        'question': question.question,
        'options': question.options,
      },
    ));
    _awaitingInput = true;
    notifyListeners();
  }

  void submitQuizAnswer(String optionKey) {
    if (_quizIndex >= _quizQuestions.length || !_awaitingInput) return;
    final question = _quizQuestions[_quizIndex];
    _awaitingInput = false;

    _push(ClassChatMessage(
      id: _newId(),
      stepId: 'AF-QUIZ-QUESTION',
      sender: ClassChatSender.user,
      contentType: ClassChatContentType.quizAnswerEcho,
      text: question.options[optionKey] ?? optionKey,
    ));

    final isCorrect = optionKey == question.answerKey;
    if (isCorrect) {
      _quizCorrectCount++;
      _accumulatedQuizPoints += _quizPointsPerCorrectAnswer;
    }

    final feedbackStepId = isCorrect ? 'AF-QUIZ-CORRECT' : 'AF-QUIZ-WRONG';
    final feedbackStep = _flow.step(feedbackStepId);
    _push(ClassChatMessage(
      id: _newId(),
      stepId: feedbackStepId,
      sender: ClassChatSender.bot,
      contentType: ClassChatContentType.quizFeedback,
      text: isCorrect
          ? _interpolate(feedbackStep?.displayText ?? 'Nailed it! +{{quiz_points}} points',
              explicitPoints: _quizPointsPerCorrectAnswer)
          : null,
      data: {
        'isCorrect': isCorrect,
        'correctOption': question.answerKey,
        'correctOptionText': question.options[question.answerKey],
        'explanation': question.explanation,
        'earnedPoints': isCorrect ? _quizPointsPerCorrectAnswer : null,
      },
    ));

    _quizIndex++;
    final hasMore = _quizIndex < _quizQuestions.length;
    final autoAdvanceMs = isCorrect ? 1500 : 2500;
    _scheduleAutoAdvance(autoAdvanceMs, () {
      if (hasMore) {
        _runStep('AF-QUIZ-QUESTION');
      } else {
        _runStep('AF-011');
      }
    });
  }

  void _emitQuizSummaryStep(FlowStepModel step) {
    _push(ClassChatMessage(
      id: _newId(),
      stepId: step.stepId,
      sender: ClassChatSender.bot,
      contentType: ClassChatContentType.quizSummary,
      text: _interpolate(step.displayText ?? 'Quiz complete!'),
      data: {'correct': _quizCorrectCount, 'total': _quizQuestions.length},
    ));
    _awaitingInput = false;
    unawaited(_revealSubmissionReviewThenPause());
  }

  /// Resolves the pending Groq submission review (if any), shows it, and
  /// only adds submission points to the running total when the review
  /// actually passed. Either way this ends by pausing on "Continue" so the
  /// learner has time to read the feedback before points are saved and the
  /// reveal screen appears.
  Future<void> _revealSubmissionReviewThenPause() async {
    final pending = _pendingReviewFuture;
    _pendingReviewFuture = null;

    if (pending == null || _submissionUsedHardcodedReply) {
      _awaitingContinue = true;
      notifyListeners();
      return;
    }

    try {
      final data = await pending;
      final review = data['review'];

      if (data['success'] == true && review is Map) {
        final reviewMap = Map<String, dynamic>.from(review);
        final verdict = reviewMap['verdict'] as String?;
        final score = (reviewMap['score'] as num?)?.toInt() ?? 0;
        final passed = verdict == 'pass' || (verdict != 'fail' && score >= _minPassingScore);

        if (passed) {
          _accumulatedSubmissionPoints += _currentUnit.xp;
          _submissionAcceptedThisUnit = true;
          final bumped = await _archetypeProgressionRepository.bumpAfterAcceptedSubmission(learnerId);
          _learnerState.archetype = bumped;
        } else {
          _submissionAcceptedThisUnit = false;
        }

        _push(ClassChatMessage(
          id: _newId(),
          stepId: 'AF-008',
          sender: ClassChatSender.bot,
          contentType: ClassChatContentType.submissionReview,
          text: passed
              ? _interpolate(_flow.step('AF-008')?.displayText ?? 'Great work! +{{submission_points}} points.',
                  explicitPoints: _currentUnit.xp)
              : (reviewMap['feedback'] as String? ??
                  "That's a good try — let's keep practicing this one."),
          data: {
            'score': score,
            'passed': passed,
            'feedback': reviewMap['feedback'],
            'strengths': reviewMap['strengths'],
            'improvements': reviewMap['improvements'],
          },
        ));
      } else {
        _push(ClassChatMessage(
          id: _newId(),
          stepId: 'AF-008',
          sender: ClassChatSender.bot,
          contentType: ClassChatContentType.submissionReview,
          text: _interpolate(_flow.step('AF-008')?.displayText ?? "We'll review this one shortly."),
        ));
      }
    } catch (_) {
      _push(ClassChatMessage(
        id: _newId(),
        stepId: 'AF-008',
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.submissionReview,
        text: _interpolate(_flow.step('AF-008')?.displayText ?? "We'll review this one shortly."),
      ));
    }

    _awaitingContinue = true;
    notifyListeners();
  }

  void continueAfterReview() {
    if (!_awaitingContinue) return;
    _awaitingContinue = false;
    unawaited(_completeUnitThenReveal());
  }

  bool _stateSaysCapped(LearnerStateModel state) {
    final bingeing = state.isBingeing ?? false;
    final remaining = state.unitsRemaining;
    return bingeing || (remaining != null && remaining <= 0);
  }

  Future<LearnerStateModel> _authoritativeStateAfterSubmit(LearnerStateModel fromSubmit) async {
    try {
      final refreshed = await _learnerStateRepository.fetchState(
        learnerId: learnerId,
        forceRefresh: true,
      );
      return refreshed;
    } catch (_) {
      return fromSubmit;
    }
  }

  Future<void> _completeUnitThenReveal() async {
    if (_hasCompletedUnit) return;
    _hasCompletedUnit = true;

    _push(ClassChatMessage(
      id: _newId(),
      stepId: 'SAVING',
      sender: ClassChatSender.bot,
      contentType: ClassChatContentType.loading,
    ));
    notifyListeners();

    try {
      final unitKey = _currentUnit.name;
      final totalXp = sessionTotalPoints > 0 ? sessionTotalPoints : 10;

      final submittedState = await _learnerStateRepository.submitProgress(
        learnerId: learnerId,
        xp: totalXp,
        activityType: 'unit_complete',
        videoIndex: unitIndex + (_videoWatchedThisUnit ? 1 : 0),
        quizIndex: unitIndex + (_quizCorrectCount > 0 ? 1 : 0),
        submissionIndex: _submissionAcceptedThisUnit ? unitIndex + 1 : null,
      );

      final confirmedState = await _authoritativeStateAfterSubmit(submittedState);
      _learnerState = _reconcileArchetype(confirmedState);

      await _sessionWindowRepository.markUnitCompleted(
        learnerId: learnerId,
        unitKey: unitKey,
        windowResetsOn: _learnerState.windowResetsOn,
        windowStartDate: _learnerState.windowStartDate,
      );

      _messages.removeWhere((m) => m.stepId == 'SAVING');

      final reachedCap = _stateSaysCapped(_learnerState);

      _outcome = reachedCap ? ClassSessionOutcome.weeklyCapReached : ClassSessionOutcome.choice;
      notifyListeners();
    } on ProgressConflictException {
      _hasCompletedUnit = false;
      try {
        final refreshed =
            await _learnerStateRepository.fetchState(learnerId: learnerId, forceRefresh: true);
        _learnerState = refreshed;
        _messages.removeWhere((m) => m.stepId == 'SAVING');
        final reachedCap = _stateSaysCapped(_learnerState);
        _outcome = reachedCap ? ClassSessionOutcome.weeklyCapReached : ClassSessionOutcome.choice;
        notifyListeners();
      } catch (_) {
        _messages.removeWhere((m) => m.stepId == 'SAVING');
        _errorMessage = 'We could not save your progress. Please check your connection.';
        _push(ClassChatMessage(
          id: _newId(),
          stepId: 'ERROR',
          sender: ClassChatSender.bot,
          contentType: ClassChatContentType.errorRetry,
          text: _errorMessage,
        ));
        notifyListeners();
      }
    } catch (_) {
      _hasCompletedUnit = false;
      _messages.removeWhere((m) => m.stepId == 'SAVING');
      _errorMessage = 'Something went wrong saving your progress.';
      _push(ClassChatMessage(
        id: _newId(),
        stepId: 'ERROR',
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.errorRetry,
        text: _errorMessage,
      ));
      notifyListeners();
    }
  }

  bool _hasCompletedUnit = false;

  LearnerStateModel _reconcileArchetype(LearnerStateModel serverState) {
    if (serverState.archetype != null && serverState.archetype!.isNotEmpty) {
      return serverState;
    }
    final localArchetype = LocalArchetypeCalculator.compute(
      streak: serverState.streak ?? 0,
      submissionCount: serverState.submissionIndex ?? 0,
      lastActivityDate: serverState.lastActivityDate,
      now: DateTime.now(),
    );
    serverState.archetype = localArchetype;
    return serverState;
  }

  void retryAfterError() {
    _messages.removeWhere((m) => m.stepId == 'ERROR');
    _errorMessage = null;
    unawaited(_completeUnitThenReveal());
  }

  void _scheduleAutoAdvance(int ms, VoidCallback callback) {
    final timer = Timer(Duration(milliseconds: ms), () {
      if (_disposed) return;
      callback();
    });
    _pendingTimers.add(timer);
  }

  void _push(ClassChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  String _newId() {
    _msgCounter++;
    return 'msg_$_msgCounter';
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _pendingTimers) {
      timer.cancel();
    }
    _pendingTimers.clear();
    super.dispose();
  }
}
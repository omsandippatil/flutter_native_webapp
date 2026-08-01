import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/learner_state_model.dart';
import '../data/repositories/archetype_progression_repository.dart';
import '../data/repositories/learner_state_repository.dart';
import '../data/repositories/submission_review_repository.dart';
import '../models/activity_flow_model.dart';
import '../models/archetype_step_selector.dart';
import '../models/class_chat_message_model.dart';
import '../models/classroom_progress_stage.dart';
import '../models/enrollment_model.dart';
import '../models/learner_archetype.dart';
import '../models/local_archetype_calculator.dart';
import '../models/program_content/course_detail_model.dart';
import '../models/submission_answer_model.dart';
import 'class_session_window_repository.dart';

enum ClassSessionOutcome { none, choice, weeklyCapReached }

const int _quizPointsPerCorrectAnswer = 5;

class ClassQuizToast {
  const ClassQuizToast({
    required this.id,
    required this.isCorrect,
    required this.points,
    this.correctAnswer,
  });

  final int id;
  final bool isCorrect;
  final int points;
  final String? correctAnswer;
}

class ClassChatController extends ChangeNotifier {
  ClassChatController({
    required this.learnerId,
    required this.phone,
    required this.studentName,
    required this.courseDisplay,
    required ActivityFlowModel flow,
    required CourseUnitModel unit,
    CourseUnitModel? nextUnit,
    required this.unitIndex,
    required LearnerStateModel initialLearnerState,
    required LearnerStateRepository learnerStateRepository,
    required SubmissionReviewRepository submissionReviewRepository,
    required ClassSessionWindowRepository sessionWindowRepository,
    required ArchetypeProgressionRepository archetypeProgressionRepository,
    VoidCallback? onProgressSaved,
  }) : _flow = flow,
       _unit = unit,
       _nextUnit = nextUnit,
       _learnerStateRepository = learnerStateRepository,
       _submissionReviewRepository = submissionReviewRepository,
       _sessionWindowRepository = sessionWindowRepository,
       _archetypeProgressionRepository = archetypeProgressionRepository,
       _learnerState = initialLearnerState,
       _startingPoints = initialLearnerState.xp ?? 0,
       _onProgressSaved = onProgressSaved {
    _begin();
  }

  final String learnerId;
  final String phone;
  final String studentName;
  final String courseDisplay;
  final int unitIndex;

  String get unitName => _unit.name;
  bool get hasNextUnit => _nextUnit != null;
  String get nextUnitName => _nextUnit?.name ?? _unit.name;
  int get nextUnitPoints => _nextUnit?.xp ?? 0;

  final ActivityFlowModel _flow;
  final CourseUnitModel _unit;
  final CourseUnitModel? _nextUnit;
  final LearnerStateRepository _learnerStateRepository;
  final SubmissionReviewRepository _submissionReviewRepository;
  final ClassSessionWindowRepository _sessionWindowRepository;
  final ArchetypeProgressionRepository _archetypeProgressionRepository;
  final VoidCallback? _onProgressSaved;

  LearnerStateModel _learnerState;
  LearnerStateModel get learnerState => _learnerState;
  final int _startingPoints;

  String get _currentArchetype =>
      LearnerArchetype.normalize(_learnerState.archetype);

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
  int _completedUnitPoints = 0;
  bool _videoWatchedThisUnit = false;
  bool _submissionAcceptedThisUnit = false;
  bool _videoProgressSaved = false;
  bool _submissionProgressSaved = false;
  bool _quizProgressSaved = false;
  bool _archetypeProgressionApplied = false;
  bool _submissionRewardShown = false;
  int _quizToastId = 0;
  ClassQuizToast? _quizToast;
  ClassQuizToast? get quizToast => _quizToast;

  CourseAssignmentStepModel? _pendingAssignmentStep;
  CourseAssignmentModel? _pendingAssignment;
  int _assignmentStepIndex = 0;

  final List<Timer> _pendingTimers = [];
  int _msgCounter = 0;

  CourseUnitModel get _currentUnit => _unit;
  CourseVideoModel? get _currentVideo {
    final vids = _currentUnit.videos;
    return vids.isNotEmpty ? vids.first : null;
  }

  CourseAssignmentModel? get _currentAssignment =>
      ArchetypeStepSelector.selectAssignment(
        _currentUnit.assignments,
        _currentArchetype,
      );

  List<CourseQuizQuestionModel> get _quizQuestions =>
      _currentUnit.quiz?.questions ?? const [];

  int get sessionTotalPoints =>
      _accumulatedVideoPoints +
      _accumulatedSubmissionPoints +
      _accumulatedQuizPoints;

  int get startingPoints => _startingPoints;

  int get displayedTotalPoints => startingPoints + sessionTotalPoints;

  Future<void> deferNextActivity() => _learnerStateRepository
      .showHomeCelebration(learnerId, points: _completedUnitPoints);

  ClassroomProgressStage get currentProgressStage {
    if (!_videoWatchedThisUnit) return ClassroomProgressStage.watchVideo;
    if (!_submissionAcceptedThisUnit) {
      return ClassroomProgressStage.submitProject;
    }
    if (!_quizProgressSaved) return ClassroomProgressStage.takeQuiz;
    return ClassroomProgressStage.unitCompleted;
  }

  double get revealProgress => currentProgressStage.revealProgress;

  bool get _submissionNotRequired =>
      _currentAssignment == null || _currentAssignment!.steps.isEmpty;

  bool get _quizNotRequired => _quizQuestions.isEmpty;

  bool get _hasCompletedRequiredStages =>
      _videoWatchedThisUnit &&
      (_submissionNotRequired || _submissionAcceptedThisUnit) &&
      (_quizNotRequired || _quizProgressSaved);

  void _resumeCurrentStage() {
    switch (currentProgressStage) {
      case ClassroomProgressStage.watchVideo:
        _showVideoStartCheckpoint();
        return;
      case ClassroomProgressStage.submitProject:
        _runStep('AF-006');
        return;
      case ClassroomProgressStage.takeQuiz:
        _showQuizStartCheckpoint();
        return;
      case ClassroomProgressStage.unitCompleted:
        return;
    }
  }

  void _begin() {
    final enrollment = _learnerState.enrollment;
    final progress = ClassroomProgressResolver.resolve(
      enrollment: enrollment ?? const EnrollmentModel(),
      unitIndex: unitIndex,
      unit: _currentUnit,
      learnerSubmissionIndex: _learnerState.submissionIndex,
    );
    _videoWatchedThisUnit = progress.videoDone;
    _submissionAcceptedThisUnit = progress.submissionDone;
    _videoProgressSaved = _videoWatchedThisUnit;
    _submissionProgressSaved = _submissionAcceptedThisUnit;
    _quizProgressSaved = progress.quizDone;

    switch (progress.stage) {
      case ClassroomProgressStage.watchVideo:
        _runStep('AF-001');
        return;
      case ClassroomProgressStage.submitProject:
        _runStep('AF-006');
        return;
      case ClassroomProgressStage.takeQuiz:
        _showQuizStartCheckpoint();
        return;
      case ClassroomProgressStage.unitCompleted:
        if (_learnerState.hasPendingLocalProgress) {
          unawaited(_completeUnitThenReveal());
          return;
        }
        _outcome = _stateSaysCapped(_learnerState)
            ? ClassSessionOutcome.weeklyCapReached
            : ClassSessionOutcome.choice;
        notifyListeners();
        return;
    }
  }

  String _interpolate(String template, {int? explicitPoints}) {
    final unit = _currentUnit;
    final hour = DateTime.now().hour;
    final partOfDay = hour < 12
        ? 'morning'
        : (hour < 17 ? 'afternoon' : 'evening');
    return template
        .replaceAll('{{name}}', studentName)
        .replaceAll('{{part_of_day}}', partOfDay)
        .replaceAll('{{unit_name}}', unit.name)
        .replaceAll('{{course_display}}', courseDisplay)
        .replaceAll(
          '{{video_description}}',
          _currentVideo?.description ?? unit.description,
        )
        .replaceAll(
          '{{video_points}}',
          '${explicitPoints ?? _currentVideo?.points ?? 0}',
        )
        .replaceAll('{{submission_points}}', '${explicitPoints ?? unit.xp}')
        .replaceAll(
          '{{quiz_points}}',
          '${explicitPoints ?? _quizPointsPerCorrectAnswer}',
        )
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
        _showVideoStartCheckpoint();
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
    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: step.stepId,
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.text,
        text: _interpolate(step.displayText ?? ''),
      ),
    );
    _awaitingInput = false;
    notifyListeners();

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
    _push(
      ClassChatMessage(
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
      ),
    );
    _awaitingInput = true;
    notifyListeners();
  }

  Future<void> markVideoWatched() async {
    final msgIndex = _messages.lastIndexWhere(
      (m) => m.stepId == 'AF-004' && !m.isPending,
    );
    final video = _currentVideo;
    if (video == null || _videoWatchedThisUnit) return;

    _videoWatchedThisUnit = true;
    _accumulatedVideoPoints += video.points;
    _awaitingInput = false;

    if (msgIndex != -1) {
      _messages[msgIndex] = _messages[msgIndex].copyWith(
        data: {..._messages[msgIndex].data, 'watched': true},
      );
    }

    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: 'AF-004',
        sender: ClassChatSender.user,
        contentType: ClassChatContentType.text,
        text: 'I watched it',
      ),
    );

    final saved = await _saveVideoProgress(video.points);
    if (_disposed) return;
    if (!saved) {
      _showProgressSaveRetry(
        'We could not save that you watched the video. Please check your connection and retry.',
        action: 'save_video',
      );
      return;
    }

    _awaitingInput = false;
    _pushCheckpoint(
      stepId: 'VIDEO-CHECKPOINT',
      image: 'assets/class-screen/10Points.png',
      text:
          'Wow! That’s amazing 🌟 $studentName, you just earned ${video.points} points for watching the video 🥳🥳🥳\n\nNow it’s time to do the activity submission 🌟',
      buttonLabel: 'Continue',
      action: 'video_reward',
    );
    notifyListeners();
  }

  void _emitAssignmentStep(FlowStepModel step) {
    final assignment = _currentAssignment;
    if (assignment == null || assignment.steps.isEmpty) {
      _submissionAcceptedThisUnit = true;
      _showQuizStartCheckpoint();
      return;
    }

    if (_assignmentStepIndex >= assignment.steps.length) {
      unawaited(_persistFinishedSubmissionAndShowQuiz());
      return;
    }

    final assignStep = assignment.steps[_assignmentStepIndex];
    _pendingAssignment = assignment;
    _pendingAssignmentStep = assignStep;

    final kind = SubmissionKindResolver.fromSubTypes(assignStep.subTypes);

    _push(
      ClassChatMessage(
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
          'validCriteria': assignStep.validCriteria,
          'submissionKind': kind.name,
          'archetype': _currentArchetype,
          'points': _currentUnit.xp,
          'stepNumber': _assignmentStepIndex + 1,
          'stepTotal': assignment.steps.length,
        },
      ),
    );
    _awaitingInput = true;
    notifyListeners();
  }

  SubmissionKind get currentSubmissionKind {
    final step = _pendingAssignmentStep;
    if (step == null) return SubmissionKind.text;
    return SubmissionKindResolver.fromSubTypes(step.subTypes);
  }

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

  bool _isFinalAssignmentStep(CourseAssignmentModel assignment) =>
      _assignmentStepIndex + 1 >= assignment.steps.length;

  String _finalSubmissionPraise() => _interpolate(
    _flow.step('AF-008')?.displayText ??
        'I am SO proud of you {{name}} 🥹 That\'s the spirit! [+{{submission_points}} pts]',
    explicitPoints: _currentUnit.xp,
  );

  Future<void> submitAssignmentAnswer(SubmissionAnswer answer) async {
    final step = _pendingAssignmentStep;
    final assignment = _pendingAssignment;
    if (step == null || assignment == null || !_awaitingInput) return;

    _awaitingInput = false;

    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: 'AF-007',
        sender: ClassChatSender.user,
        contentType: ClassChatContentType.submissionAnswerEcho,
        text: answer.displaySummary,
        data: {
          'kind': answer.kind.name,
          'text': answer.text,
          'emoji': answer.emoji,
        },
      ),
    );

    final isMediaSubmission =
        answer.kind == SubmissionKind.image ||
        answer.kind == SubmissionKind.video ||
        answer.kind == SubmissionKind.imageVideo;
    final needsAiReview =
        !isMediaSubmission &&
        SubmissionKindResolver.requiresAiReview(answer.kind);
    final hardcodedReply = _hardcodedReplyFor(answer);

    if (!needsAiReview || hardcodedReply != null) {
      final passed = isMediaSubmission
          ? true
          : (!needsAiReview
                ? answer.matchesCriteria(step.validCriteria)
                : true);
      final isFinalStep = passed && _isFinalAssignmentStep(assignment);
      _push(
        ClassChatMessage(
          id: _newId(),
          stepId: 'AF-008',
          sender: ClassChatSender.bot,
          contentType: ClassChatContentType.submissionReview,
          text: passed
              ? (isFinalStep
                    ? _finalSubmissionPraise()
                    : hardcodedReply ?? 'Great work — this step is complete.')
              : "That's a good try — let's keep practicing this one.",
          data: {'passed': passed, 'isFinalStep': isFinalStep},
        ),
      );
      await _finishAssignmentStep(accepted: passed);
      return;
    }

    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: 'AF-008-REVIEWING',
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.submissionReviewing,
      ),
    );
    notifyListeners();

    try {
      final data = await _submissionReviewRepository.reviewSubmission(
        phone: phone,
        learnerId: learnerId,
        submissionText: answer.text ?? step.unguidedText,
        question: assignment.description,
        expectedAnswer: step.validCriteria,
        rubric: null,
      );
      _messages.removeWhere((m) => m.stepId == 'AF-008-REVIEWING');
      final review = data['review'];
      final reviewMap = review is Map
          ? Map<String, dynamic>.from(review)
          : const <String, dynamic>{};
      final passed = data['success'] == true && reviewMap['verdict'] == 'pass';
      final isFinalStep = passed && _isFinalAssignmentStep(assignment);
      _push(
        ClassChatMessage(
          id: _newId(),
          stepId: 'AF-008',
          sender: ClassChatSender.bot,
          contentType: ClassChatContentType.submissionReview,
          text: passed
              ? (isFinalStep
                    ? _finalSubmissionPraise()
                    : 'Great work — this step is complete.')
              : (reviewMap['feedback'] as String?) ??
                    "That submission didn't quite pass this time — let's try again.",
          data: {
            'score': (reviewMap['score'] as num?)?.toInt(),
            'passed': passed,
            'isFinalStep': isFinalStep,
            'feedback': reviewMap['feedback'],
            'smsText': reviewMap['sms_text'],
            'strengths': reviewMap['strengths'],
            'improvements': reviewMap['improvements'],
          },
        ),
      );
      await _finishAssignmentStep(accepted: passed);
    } catch (_) {
      _messages.removeWhere((m) => m.stepId == 'AF-008-REVIEWING');
      await _finishAssignmentStep(accepted: false);
    }
  }

  Future<void> _finishAssignmentStep({required bool accepted}) async {
    _pendingAssignment = null;
    _pendingAssignmentStep = null;
    if (accepted) {
      _assignmentStepIndex++;
      final assignment = _currentAssignment;
      if (assignment != null &&
          _assignmentStepIndex < assignment.steps.length) {
        final step = _flow.step('AF-007');
        if (step != null) _emitAssignmentStep(step);
        return;
      }

      _submissionAcceptedThisUnit = true;
      _accumulatedSubmissionPoints += _currentUnit.xp;
      // The final compact review card has already been emitted above. Persist
      // the checkpoint only after that reward is visible, and expose the quiz
      // only after the persisted state confirms the submission is complete.
      final saved = await _saveSubmissionProgress(_currentUnit.xp);
      if (_disposed) return;
      if (!saved) {
        _showProgressSaveRetry(
          'We could not save your completed submission. Please check your connection and retry.',
          action: 'save_submission',
        );
        return;
      }
      await _continueToQuizAfterSavedSubmission();
    } else {
      _pushCheckpoint(
        stepId: 'SUBMISSION-RETRY',
        image: null,
        text:
            'Pro tip: Take the photo in good light and show your full work 📸✨\n\nI’m excited to see what you made😅\nYou can do this! ⭐💪',
        buttonLabel: 'Submit Again',
        action: 'submission_retry',
      );
    }
  }

  Future<void> _persistFinishedSubmissionAndShowQuiz() async {
    _submissionAcceptedThisUnit = true;
    final saved = await _saveSubmissionProgress(_currentUnit.xp);
    if (_disposed) return;
    if (!saved) {
      _showProgressSaveRetry(
        'We could not save your completed submission. Please check your connection and retry.',
        action: 'save_submission',
      );
      return;
    }
    await _continueToQuizAfterSavedSubmission();
  }

  void _emitQuizQuestionStep(FlowStepModel step) {
    if (_quizIndex >= _quizQuestions.length) {
      _runStep('AF-011');
      return;
    }
    final question = _quizQuestions[_quizIndex];
    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: step.stepId,
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.quizQuestion,
        data: {
          'questionIndex': _quizIndex,
          'totalQuestions': _quizQuestions.length,
          'question': question.question,
          'options': question.options,
          'answerKey': question.answerKey,
        },
      ),
    );
    _awaitingInput = true;
    notifyListeners();
  }

  void submitQuizAnswer(String optionKey) {
    if (_quizIndex >= _quizQuestions.length || !_awaitingInput) return;
    final question = _quizQuestions[_quizIndex];
    _awaitingInput = false;

    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: 'AF-QUIZ-QUESTION',
        sender: ClassChatSender.user,
        contentType: ClassChatContentType.quizAnswerEcho,
        text: question.options[optionKey] ?? optionKey,
      ),
    );

    final isCorrect = optionKey == question.answerKey;
    if (isCorrect) {
      _quizCorrectCount++;
      _accumulatedQuizPoints += _quizPointsPerCorrectAnswer;
    }

    _quizToast = ClassQuizToast(
      id: ++_quizToastId,
      isCorrect: isCorrect,
      points: isCorrect ? _quizPointsPerCorrectAnswer : 0,
      correctAnswer: isCorrect ? null : question.options[question.answerKey],
    );
    notifyListeners();

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
    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: step.stepId,
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.quizSummary,
        text: _interpolate(step.displayText ?? 'Quiz complete!'),
        data: {'correct': _quizCorrectCount, 'total': _quizQuestions.length},
      ),
    );
    _awaitingInput = false;
    unawaited(_saveQuizThenShowTotals());
  }

  void _showQuizStartCheckpoint({bool replaceThread = false}) {
    if (replaceThread) {
      _messages.clear();
    }
    _pushCheckpoint(
      stepId: 'QUIZ-START',
      image: 'assets/class-screen/lets_begin.png',
      text: "Let’s start the ${_currentUnit.name} quiz🚀🚀🚀",
      buttonLabel: 'Quiz',
      action: 'quiz',
    );
  }

  void _showVideoStartCheckpoint() {
    _pushCheckpoint(
      stepId: 'VIDEO-START',
      image: null,
      text:
          "Today we're going to play with ${_currentUnit.name}.\nWatch a short video, then make your own project.",
      buttonLabel: 'Watch',
      action: 'video',
    );
  }

  void _pushCheckpoint({
    required String stepId,
    required String? image,
    required String text,
    required String buttonLabel,
    required String action,
  }) {
    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: stepId,
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.checkpoint,
        text: text,
        data: {
          // ignore: use_null_aware_elements
          if (image != null) 'image': image,
          'buttonLabel': buttonLabel,
          'action': action,
        },
      ),
    );
    _awaitingInput = false;
    notifyListeners();
  }

  void continueCheckpoint(String action) {
    switch (action) {
      case 'video':
        _messages.clear();
        final step = _flow.step('AF-004');
        if (step != null) _emitVideoStep(step);
        return;
      case 'submission':
        _messages.clear();
        _runStep('AF-006');
        return;
      case 'video_reward':
        _messages.clear();
        _runStep('AF-006');
        return;
      case 'submission_retry':
        _messages.clear();
        final step = _flow.step('AF-007');
        if (step != null) _emitAssignmentStep(step);
        return;
      case 'quiz':
        _messages.clear();
        _push(
          ClassChatMessage(
            id: _newId(),
            stepId: 'QUIZ-START-ECHO',
            sender: ClassChatSender.user,
            contentType: ClassChatContentType.text,
            text: 'Quiz',
          ),
        );
        _pushCheckpoint(
          stepId: 'QUIZ-BEGIN',
          image: 'assets/class-screen/lets_begin.png',
          text: '',
          buttonLabel: '',
          action: 'quiz_begin_art',
        );
        _scheduleAutoAdvance(1200, () => _runStep('AF-QUIZ-QUESTION'));
        return;
      case 'save_submission':
        _messages.removeWhere((m) => m.stepId == 'ERROR');
        unawaited(_retrySaveSubmissionThenShowQuiz());
        return;
      case 'save_video':
        _messages.removeWhere((m) => m.stepId == 'ERROR');
        unawaited(_retrySaveVideoThenShowSubmission());
        return;
      case 'save_quiz':
        _messages.removeWhere((m) => m.stepId == 'ERROR');
        unawaited(_saveQuizThenShowTotals());
        return;
      case 'totals':
        _showFinalWinCard();
        return;
      case 'finish':
        unawaited(_completeUnitThenReveal());
        return;
    }
  }

  void _showFinalWinCard() {
    _pushCheckpoint(
      stepId: 'FINAL-WIN',
      image: 'assets/class-screen/you-won.png',
      text:
          'Activity Points    ${_accumulatedVideoPoints + _accumulatedSubmissionPoints} 🪙\nQuiz Points    $_accumulatedQuizPoints 🪙\nSkill Gems    ${_submissionAcceptedThisUnit ? 1 : 0} 💎\nSubmission Streak    ${_submissionAcceptedThisUnit ? 1 : 0} 🔥',
      buttonLabel: 'Continue',
      action: 'finish',
    );
  }

  Future<void> _saveQuizThenShowTotals() async {
    final saved = await _saveQuizProgress(_accumulatedQuizPoints);
    if (_disposed) return;
    if (!saved) {
      _showProgressSaveRetry(
        'We could not save your quiz result. Please check your connection and retry.',
        action: 'save_quiz',
      );
      return;
    }
    _pushCheckpoint(
      stepId: 'QUIZ-COMPLETE-ART',
      image: 'assets/class-screen/won-champ.png',
      text: '',
      buttonLabel: '',
      action: 'quiz_complete_art',
    );
    _scheduleAutoAdvance(1200, () {
      _pushCheckpoint(
        stepId: 'QUIZ-TOTALS',
        image: null,
        text:
            'Great job Champ!\nDo you want to know your total points and gems collected so far?',
        buttonLabel: 'Yes Yes Yes 😍',
        action: 'totals',
      );
    });
  }

  void _showProgressSaveRetry(String message, {required String action}) {
    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: 'ERROR',
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.errorRetry,
        text: message,
        data: {'action': action},
      ),
    );
    notifyListeners();
  }

  Future<void> _retrySaveSubmissionThenShowQuiz() async {
    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: 'SAVING',
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.loading,
      ),
    );
    notifyListeners();

    final saved = await _saveSubmissionProgress(_currentUnit.xp);
    if (_disposed) return;
    _messages.removeWhere((m) => m.stepId == 'SAVING');

    if (!saved) {
      _showProgressSaveRetry(
        'Still could not save your submission progress. Please check your connection and retry.',
        action: 'save_submission',
      );
      return;
    }

    await _continueToQuizAfterSavedSubmission();
    notifyListeners();
  }

  Future<void> _continueToQuizAfterSavedSubmission() async {
    if (!_archetypeProgressionApplied) {
      try {
        final bumped = await _archetypeProgressionRepository
            .bumpAfterAcceptedSubmission(learnerId);
        if (_disposed) return;
        _learnerState.archetype = bumped;
      } catch (_) {
        // Archetype decoration is secondary; the server-confirmed submission
        // checkpoint must still advance to the quiz.
      }
      _archetypeProgressionApplied = true;
    }
    if (!_submissionRewardShown) {
      _messages.clear();
      _push(
        ClassChatMessage(
          id: _newId(),
          stepId: 'SUBMISSION-REWARD',
          sender: ClassChatSender.bot,
          contentType: ClassChatContentType.submissionReward,
          data: {'studentName': studentName, 'points': _currentUnit.xp},
        ),
      );
      _submissionRewardShown = true;
      notifyListeners();
    }
  }

  void continueAfterSubmissionReward() {
    if (!_submissionRewardShown) return;
    _messages.clear();
    _showQuizStartCheckpoint();
  }

  Future<void> _retrySaveVideoThenShowSubmission() async {
    final video = _currentVideo;
    if (video == null) return;

    final saved = await _saveVideoProgress(video.points);
    if (_disposed) return;
    if (!saved) {
      _showProgressSaveRetry(
        'We still could not save the video checkpoint. Please check your connection and retry.',
        action: 'save_video',
      );
      return;
    }

    _pushCheckpoint(
      stepId: 'VIDEO-CHECKPOINT',
      image: 'assets/class-screen/10Points.png',
      text:
          'Wow! That’s amazing 🌟 $studentName, you completed the video.\n\nNow it’s time to do the activity submission 🌟',
      buttonLabel: 'Continue',
      action: 'video_reward',
    );
  }

  Future<bool> _saveVideoProgress(int points) async {
    if (_videoProgressSaved) return true;
    _videoProgressSaved = true;
    var saved = false;
    try {
      _learnerState = await _learnerStateRepository.applyLocalProgress(
        learnerId: learnerId,
        xp: points,
        videoIndex: unitIndex + 1,
      );
      saved = true;
    } catch (_) {
      saved = false;
    }
    _videoProgressSaved = saved;
    if (saved) _onProgressSaved?.call();
    return saved;
  }

  Future<bool> _saveSubmissionProgress(int points) async {
    if (_submissionProgressSaved) return true;
    _submissionProgressSaved = true;
    var saved = false;
    try {
      _learnerState = await _learnerStateRepository.applyLocalProgress(
        learnerId: learnerId,
        xp: points,
        submissionIndex: unitIndex + 1,
      );
      saved = true;
    } catch (_) {
      saved = false;
    }
    _submissionProgressSaved = saved;
    if (saved) _onProgressSaved?.call();
    return saved;
  }

  Future<bool> _saveQuizProgress(int points) async {
    if (_quizProgressSaved) return true;
    _quizProgressSaved = true;
    var saved = false;
    try {
      _learnerState = await _learnerStateRepository.applyLocalProgress(
        learnerId: learnerId,
        xp: points,
        quizIndex: unitIndex + 1,
      );
      saved = true;
    } catch (_) {
      saved = false;
    }
    _quizProgressSaved = saved;
    if (saved) _onProgressSaved?.call();
    return saved;
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

  Future<LearnerStateModel> _authoritativeStateAfterSubmit(
    LearnerStateModel fromSubmit,
  ) async {
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

    if (!_hasCompletedRequiredStages) {
      _resumeCurrentStage();
      notifyListeners();
      return;
    }

    _hasCompletedUnit = true;

    _push(
      ClassChatMessage(
        id: _newId(),
        stepId: 'SAVING',
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.loading,
      ),
    );
    notifyListeners();

    try {
      final unitKey = _currentUnit.name;
      await _learnerStateRepository.markLocalProgressReady(learnerId);
      _completedUnitPoints = _learnerState.pendingProgressXp > 0
          ? _learnerState.pendingProgressXp
          : sessionTotalPoints;

      final submittedState = await _learnerStateRepository.submitProgress(
        learnerId: learnerId,
        xp: _completedUnitPoints > 0 ? _completedUnitPoints : null,
        activityType: 'unit_complete',
        videoIndex: _videoWatchedThisUnit ? unitIndex + 1 : null,
        quizIndex: _quizProgressSaved ? unitIndex + 1 : null,
        submissionIndex: _submissionAcceptedThisUnit ? unitIndex + 1 : null,
      );

      final confirmedState = await _authoritativeStateAfterSubmit(
        submittedState,
      );
      _learnerState = _reconcileArchetype(confirmedState);
      if (_nextUnit != null) {
        _learnerState = await _learnerStateRepository.prepareLocalUnit(
          learnerId: learnerId,
          unitIndex: unitIndex + 1,
        );
      }
      _onProgressSaved?.call();

      await _sessionWindowRepository.markUnitCompleted(
        learnerId: learnerId,
        unitKey: unitKey,
        windowResetsOn: _learnerState.windowResetsOn,
        windowStartDate: _learnerState.windowStartDate,
      );

      _messages.clear();

      _outcome = ClassSessionOutcome.choice;
      notifyListeners();
    } on ProgressConflictException {
      _hasCompletedUnit = false;
      try {
        final refreshed = await _learnerStateRepository.fetchState(
          learnerId: learnerId,
          forceRefresh: true,
        );
        _learnerState = refreshed;
        _messages.removeWhere((m) => m.stepId == 'SAVING');
        _outcome = ClassSessionOutcome.choice;
        notifyListeners();
      } catch (_) {
        _messages.removeWhere((m) => m.stepId == 'SAVING');
        _errorMessage =
            'We could not save your progress. Please check your connection.';
        _push(
          ClassChatMessage(
            id: _newId(),
            stepId: 'ERROR',
            sender: ClassChatSender.bot,
            contentType: ClassChatContentType.errorRetry,
            text: _errorMessage,
          ),
        );
        notifyListeners();
      }
    } catch (_) {
      _hasCompletedUnit = false;
      _messages.removeWhere((m) => m.stepId == 'SAVING');
      if (_stateSaysCapped(_learnerState) &&
          _learnerState.hasPendingLocalProgress) {
        _outcome = ClassSessionOutcome.choice;
        notifyListeners();
        return;
      }
      _errorMessage = 'Something went wrong saving your progress.';
      _push(
        ClassChatMessage(
          id: _newId(),
          stepId: 'ERROR',
          sender: ClassChatSender.bot,
          contentType: ClassChatContentType.errorRetry,
          text: _errorMessage,
        ),
      );
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
    final error = _messages.lastWhere(
      (m) => m.stepId == 'ERROR',
      orElse: () => ClassChatMessage(
        id: _newId(),
        stepId: 'ERROR',
        sender: ClassChatSender.bot,
        contentType: ClassChatContentType.errorRetry,
      ),
    );
    final action = error.data['action'] as String?;
    _messages.removeWhere((m) => m.stepId == 'ERROR');
    _errorMessage = null;
    switch (action) {
      case 'save_video':
        unawaited(_retrySaveVideoThenShowSubmission());
        return;
      case 'save_submission':
        unawaited(_retrySaveSubmissionThenShowQuiz());
        return;
      case 'save_quiz':
        unawaited(_saveQuizThenShowTotals());
        return;
    }
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

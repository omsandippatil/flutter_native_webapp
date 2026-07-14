import 'package:flutter/foundation.dart';

enum ActivityMessageType {
  video,
  assignmentEmoji,
  assignmentTextAudio,
  assignmentImage,
  assignmentVoiceText,
  assignmentImageVideo,
  submissionReview,
  quizQuestion,
  quizFeedback,
  quizSummary,
  unitTransition,
  sessionComplete,
}

enum SubmissionKind {
  emoji,
  textAudio,
  image,
  voiceText,
  imageVideo,
}

class ActivityMessage {
  final String id;
  final ActivityMessageType type;
  final Map<String, dynamic> data;
  final bool fromUser;
  final DateTime timestamp;

  ActivityMessage({
    required this.id,
    required this.type,
    required this.data,
    this.fromUser = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

typedef ReviewCallback = String Function(
  Map<String, dynamic> assignment,
  Map<String, dynamic> step,
  dynamic answer,
);

class _QuizRuntimeState {
  final List<Map<String, dynamic>> questions;
  int index = 0;
  int correctCount = 0;

  _QuizRuntimeState(this.questions);

  Map<String, dynamic>? get current =>
      index < questions.length ? questions[index] : null;

  bool get isFinished => index >= questions.length;
}

enum _UnitStage {
  video,
  assignment,
  awaitingReview,
  quiz,
  quizFeedback,
  unitDone,
}

class ActivityFlowProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _units;
  final SubmissionKind submissionKind;
  final ReviewCallback? onSubmissionReview;

  final List<ActivityMessage> _messages = [];
  int _unitIndex = 0;
  _UnitStage _stage = _UnitStage.video;
  _QuizRuntimeState? _quizState;
  bool _sessionEnded = false;
  Map<String, dynamic>? _pendingAssignmentStep;
  Map<String, dynamic>? _pendingAssignment;

  ActivityFlowProvider({
    required List<Map<String, dynamic>> units,
    required this.submissionKind,
    this.onSubmissionReview,
  }) : _units = units.take(2).toList() {
    _startFlow();
  }

  List<ActivityMessage> get messages => List.unmodifiable(_messages);
  bool get isSessionComplete => _sessionEnded;
  bool get isAwaitingUserInput => _isAwaitingInput();

  Map<String, dynamic>? get _currentUnit =>
      _unitIndex < _units.length ? _units[_unitIndex] : null;

  void _startFlow() {
    if (_units.isEmpty) {
      _pushSessionComplete();
      return;
    }
    _emitVideoForCurrentUnit();
  }

  void _emitVideoForCurrentUnit() {
    final unit = _currentUnit;
    if (unit == null) {
      _pushSessionComplete();
      return;
    }
    final videos = (unit['vids'] as List?) ?? const [];
    final video = videos.isNotEmpty ? videos.first as Map<String, dynamic> : null;
    if (video == null) {
      _stage = _UnitStage.assignment;
      _emitAssignmentForCurrentUnit();
      return;
    }
    _push(ActivityMessage(
      id: _newId(),
      type: ActivityMessageType.video,
      data: {
        'unitName': unit['nm'],
        'videoId': video['id'],
        'title': video['nm'],
        'description': video['desc'],
        'youtubeId': video['yt'],
        'points': video['pts'],
      },
    ));
    _stage = _UnitStage.assignment;
  }

  void _emitAssignmentForCurrentUnit() {
    final unit = _currentUnit;
    if (unit == null) {
      _pushSessionComplete();
      return;
    }
    final assigns = (unit['assigns'] as List?) ?? const [];
    if (assigns.isEmpty) {
      _stage = _UnitStage.quiz;
      _beginQuizForCurrentUnit();
      return;
    }
    final assignment = assigns.first as Map<String, dynamic>;
    final steps = (assignment['steps'] as List?) ?? const [];
    final step = _pickStepForProfile(steps);
    if (step == null) {
      _stage = _UnitStage.quiz;
      _beginQuizForCurrentUnit();
      return;
    }
    _pendingAssignment = assignment;
    _pendingAssignmentStep = step;
    _push(ActivityMessage(
      id: _newId(),
      type: _messageTypeForKind(submissionKind),
      data: {
        'assignmentId': assignment['id'],
        'assignmentName': assignment['nm'],
        'assignmentDesc': assignment['desc'],
        'stepLabel': step['label'],
        'stepTitle': step['sub_title'],
        'guidedText': step['guided_text'],
        'unguidedText': step['unguided_text'],
        'subTypes': step['sub_types'],
      },
    ));
    _stage = _UnitStage.awaitingReview;
  }

  Map<String, dynamic>? _pickStepForProfile(List steps) {
    final target = _subTypeKeyword(submissionKind);
    for (final raw in steps) {
      final step = raw as Map<String, dynamic>;
      final types = (step['sub_types'] as String? ?? '').toLowerCase();
      if (types.contains(target)) {
        return step;
      }
    }
    return steps.isNotEmpty ? steps.first as Map<String, dynamic> : null;
  }

  String _subTypeKeyword(SubmissionKind kind) {
    switch (kind) {
      case SubmissionKind.emoji:
        return 'emoji';
      case SubmissionKind.textAudio:
        return 'text';
      case SubmissionKind.image:
        return 'image';
      case SubmissionKind.voiceText:
        return 'audio';
      case SubmissionKind.imageVideo:
        return 'video';
    }
  }

  ActivityMessageType _messageTypeForKind(SubmissionKind kind) {
    switch (kind) {
      case SubmissionKind.emoji:
        return ActivityMessageType.assignmentEmoji;
      case SubmissionKind.textAudio:
        return ActivityMessageType.assignmentTextAudio;
      case SubmissionKind.image:
        return ActivityMessageType.assignmentImage;
      case SubmissionKind.voiceText:
        return ActivityMessageType.assignmentVoiceText;
      case SubmissionKind.imageVideo:
        return ActivityMessageType.assignmentImageVideo;
    }
  }

  void submitAssignmentAnswer(dynamic answer) {
    if (_stage != _UnitStage.awaitingReview || _pendingAssignmentStep == null) {
      return;
    }
    _push(ActivityMessage(
      id: _newId(),
      type: _messageTypeForKind(submissionKind),
      data: {'answer': answer},
      fromUser: true,
    ));

    final reviewText = onSubmissionReview != null
        ? onSubmissionReview!(_pendingAssignment!, _pendingAssignmentStep!, answer)
        : null;

    _push(ActivityMessage(
      id: _newId(),
      type: ActivityMessageType.submissionReview,
      data: {'review': reviewText},
    ));

    _pendingAssignment = null;
    _pendingAssignmentStep = null;
    _stage = _UnitStage.quiz;
    _beginQuizForCurrentUnit();
  }

  void _beginQuizForCurrentUnit() {
    final unit = _currentUnit;
    if (unit == null) {
      _pushSessionComplete();
      return;
    }
    final quiz = unit['quiz'] as Map<String, dynamic>?;
    final questions = (quiz?['qs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (questions.isEmpty) {
      _finishUnit();
      return;
    }
    _quizState = _QuizRuntimeState(questions);
    _emitCurrentQuizQuestion(quiz!['nm'] as String?);
  }

  void _emitCurrentQuizQuestion(String? quizName) {
    final state = _quizState;
    final question = state?.current;
    if (state == null || question == null) {
      _finishUnit();
      return;
    }
    _push(ActivityMessage(
      id: _newId(),
      type: ActivityMessageType.quizQuestion,
      data: {
        'quizName': quizName,
        'questionIndex': state.index,
        'totalQuestions': state.questions.length,
        'question': question['q'],
        'options': question['opts'],
        'hint': question['hint'],
      },
    ));
    _stage = _UnitStage.quiz;
  }

  void submitQuizAnswer(String optionKey) {
    final state = _quizState;
    final question = state?.current;
    if (state == null || question == null) return;

    _push(ActivityMessage(
      id: _newId(),
      type: ActivityMessageType.quizQuestion,
      data: {'selectedOption': optionKey},
      fromUser: true,
    ));

    final correctKey = question['ans'] as String?;
    final isCorrect = optionKey == correctKey;
    if (isCorrect) state.correctCount++;

    _push(ActivityMessage(
      id: _newId(),
      type: ActivityMessageType.quizFeedback,
      data: {
        'isCorrect': isCorrect,
        'correctOption': correctKey,
        'explanation': question['exp'],
      },
    ));

    state.index++;
    _stage = _UnitStage.quizFeedback;
  }

  void continueAfterQuizFeedback() {
    if (_stage != _UnitStage.quizFeedback) return;
    final state = _quizState;
    if (state == null || state.isFinished) {
      _finishQuizAndUnit();
      return;
    }
    final quiz = (_currentUnit?['quiz'] as Map<String, dynamic>?);
    _emitCurrentQuizQuestion(quiz?['nm'] as String?);
  }

  void _finishQuizAndUnit() {
    final state = _quizState;
    if (state != null) {
      _push(ActivityMessage(
        id: _newId(),
        type: ActivityMessageType.quizSummary,
        data: {
          'correct': state.correctCount,
          'total': state.questions.length,
        },
      ));
    }
    _quizState = null;
    _finishUnit();
  }

  void _finishUnit() {
    _stage = _UnitStage.unitDone;
    _unitIndex++;
    if (_unitIndex < _units.length) {
      _push(ActivityMessage(
        id: _newId(),
        type: ActivityMessageType.unitTransition,
        data: {
          'nextUnitName': _units[_unitIndex]['nm'],
        },
      ));
      _stage = _UnitStage.video;
      _emitVideoForCurrentUnit();
    } else {
      _pushSessionComplete();
    }
  }

  void _pushSessionComplete() {
    _sessionEnded = true;
    _push(ActivityMessage(
      id: _newId(),
      type: ActivityMessageType.sessionComplete,
      data: {
        'message': 'You did really well this week! See you next week 🎉',
      },
    ));
  }

  bool _isAwaitingInput() {
    if (_sessionEnded) return false;
    return _stage == _UnitStage.awaitingReview || _stage == _UnitStage.quiz;
  }

  void _push(ActivityMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_messages.length}';

  void reset() {
    _messages.clear();
    _unitIndex = 0;
    _stage = _UnitStage.video;
    _quizState = null;
    _sessionEnded = false;
    _pendingAssignment = null;
    _pendingAssignmentStep = null;
    _startFlow();
  }
}
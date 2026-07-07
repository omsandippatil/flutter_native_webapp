import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/activity_provider.dart';
import '../../services/activity_progress_store.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/flow_components/quiz_card.dart';
import '../../widgets/flow_components/submission_card.dart';
import '../../widgets/flow_components/video_slot.dart';

class ActivityMessage {
  final String id;
  final String? text;
  final bool isUser;
  final Widget? child;
  final List<ActivityAction> actions;

  const ActivityMessage({
    required this.id,
    this.text,
    this.isUser = false,
    this.child,
    this.actions = const [],
  });
}

class ActivityAction {
  final String label;
  final VoidCallback onPressed;

  const ActivityAction({required this.label, required this.onPressed});
}

class ClassScreen extends ConsumerStatefulWidget {
  const ClassScreen({super.key});

  @override
  ConsumerState<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends ConsumerState<ClassScreen> {
  final _store = ActivityProgressStore();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final List<ActivityMessage> _messages = [];

  Map<String, dynamic>? _course;
  Map<String, dynamic>? _unit;
  Map<String, Map<String, dynamic>> _steps = {};
  Map<String, dynamic> _progress = {};

  String _stepId = 'AF-001';
  int _unitIndex = 0;
  int _quizIndex = 0;
  int _quizScore = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final flowRaw = await rootBundle.loadString(
      'assets/flows/en/activity/activity_flow.json',
    );
    final courseRaw = await rootBundle.loadString(
      'assets/flows/en/course/science.json',
    );
    final flow = jsonDecode(flowRaw) as Map<String, dynamic>;
    final course = jsonDecode(courseRaw) as Map<String, dynamic>;
    final saved = await _store.read();
    final units = course['units'] as List<dynamic>? ?? const [];
    final savedUnitIndex = saved?['unit_index'] as int? ?? 0;
    final unitIndex = units.isEmpty
        ? 0
        : savedUnitIndex.clamp(0, units.length - 1).toInt();
    final unit = units.isNotEmpty
        ? units[unitIndex] as Map<String, dynamic>
        : <String, dynamic>{};

    final steps = <String, Map<String, dynamic>>{};
    for (final raw in flow['steps'] as List<dynamic>? ?? const []) {
      final step = raw as Map<String, dynamic>;
      steps[step['step_id'] as String] = step;
    }

    setState(() {
      _course = course;
      _unit = unit;
      _unitIndex = unitIndex;
      _steps = steps;
      _progress = saved ?? <String, dynamic>{};
      _stepId = _progress['step_id'] as String? ?? _stageStartStep();
      _quizIndex = _progress['quiz_index'] as int? ?? 0;
      _quizScore = _progress['quiz_score'] as int? ?? 0;
      _loading = false;
    });

    _enterStep(_stepId, replace: true);
  }

  String _stageStartStep() {
    final progress = ref
        .read(learningDashboardProvider)
        .maybeWhen(data: (dashboard) => dashboard.progress, orElse: () => null);
    if (progress == null || !progress.videoDone) return 'AF-001';
    if (!progress.submissionDone) return 'AF-006';
    if (!progress.quizDone) return 'AF-009';
    return 'AF-013';
  }

  Future<void> _save() async {
    await _store.write({
      ..._progress,
      'unit_index': _unitIndex,
      'step_id': _stepId,
      'quiz_index': _quizIndex,
      'quiz_score': _quizScore,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _enterStep(String? stepId, {bool replace = false}) {
    if (stepId == null) return;
    final step = _steps[stepId];
    if (step == null) return;

    _stepId = stepId;
    _save();
    if (replace) _messages.clear();

    if (stepId == 'AF-001') {
      _messages.add(
        ActivityMessage(
          id: 'activity_start',
          child: _ActivityStartCard(
            text: _resolveText(
              _steps['AF-003']?['display_text'] as String? ?? '',
            ),
            onWatch: () => _enterStep('AF-004'),
          ),
        ),
      );
      setState(() {});
      _scrollToBottom();
      return;
    }

    if (stepId == 'AF-006') {
      _messages.add(
        ActivityMessage(
          id: 'section_start',
          child: _SectionStartCard(
            text: _resolveText(step['display_text'] as String? ?? ''),
            buttonLabel: 'Submission',
            onStart: () => _enterStep('AF-007'),
          ),
        ),
      );
      setState(() {});
      _scrollToBottom();
      return;
    }

    if (stepId == 'AF-009') {
      _messages.add(
        ActivityMessage(
          id: 'section_start',
          child: _SectionStartCard(
            text: _resolveText('Let’s start the {{unit_name}} Quiz 🚀🚀🚀'),
            buttonLabel: 'Quiz',
            onStart: () => _enterStep('AF-QUIZ-QUESTION'),
          ),
        ),
      );
      setState(() {});
      _scrollToBottom();
      return;
    }

    if (stepId == 'AF-011' && _progress['quiz_done'] != true) {
      _progress['quiz_done'] = true;
      ref.read(learningDashboardProvider.notifier).completeQuiz();
      _save();
    }

    final component = step['component'] as String?;
    if (component != null) {
      _addDynamicStep(step);
      return;
    }

    final text = _resolveText(step['display_text'] as String? ?? '');
    final options = step['options'] as List<dynamic>? ?? const [];

    _messages.add(
      ActivityMessage(
        id: '${stepId}_${_messages.length}',
        text: text,
        actions: options.isNotEmpty
            ? options.map((raw) {
                final option = raw as Map<String, dynamic>;
                return ActivityAction(
                  label: option['label'] as String? ?? 'Continue',
                  onPressed: () {
                    _addUser(option['label'] as String? ?? 'Continue');
                    _enterStep(option['next_step'] as String?);
                  },
                );
              }).toList()
            : [
                if (step['next_step'] != null)
                  ActivityAction(
                    label: _buttonLabelFor(stepId),
                    onPressed: () => _enterStep(step['next_step'] as String?),
                  ),
              ],
      ),
    );
    setState(() {});
    _scrollToBottom();
  }

  void _addDynamicStep(Map<String, dynamic> step) {
    final component = step['component'] as String;
    Widget child;

    switch (component) {
      case 'VideoPlayer':
        child = ActivityVideoSlot(
          video: _unit?['video'] as Map<String, dynamic>? ?? const {},
          onComplete: _completeVideo,
        );
        break;
      case 'SubmissionCard':
        child = ActivitySubmissionCard(
          submission: _unit?['submission'] as Map<String, dynamic>? ?? const {},
          onHelp: () => _addBot(
            'Pick the submission type shown here. It comes from your current unit, so send the work in that format.',
          ),
          onSubmit: _submitProject,
        );
        break;
      case 'QuizQuestion':
        child = ActivityQuizCard(
          question: _currentQuestion,
          questionNumber: _quizIndex + 1,
          onAnswer: _answerQuiz,
        );
        break;
      case 'QuizCorrectFeedback':
        final feedback = _currentQuestionFeedback('correct');
        _addBot(
          _resolveText(feedback['display_text'] as String? ?? 'Correct!'),
        );
        _messages.add(
          ActivityMessage(
            id: '${step['step_id']}_actions_${_messages.length}',
            actions: [
              ActivityAction(
                label: 'Continue',
                onPressed: () {
                  if (_isLastQuestion) {
                    _enterStep('AF-011');
                  } else {
                    _enterStep('AF-QUIZ-MOTIVATE');
                  }
                },
              ),
            ],
          ),
        );
        setState(() {});
        _scrollToBottom();
        return;
      case 'QuizFeedback':
        final wrong = _currentQuestionFeedback('wrong');
        _addBot(
          [
            wrong['consolation'],
            wrong['hint'],
            wrong['explanation'],
          ].whereType<String>().join('\n\n'),
        );
        _messages.add(
          ActivityMessage(
            id: '${step['step_id']}_actions_${_messages.length}',
            actions: [
              ActivityAction(
                label: 'Try again 🔁',
                onPressed: () => _enterStep('AF-QUIZ-QUESTION'),
              ),
              ActivityAction(
                label: 'Next question ➡️',
                onPressed: _nextQuizQuestion,
              ),
            ],
          ),
        );
        setState(() {});
        _scrollToBottom();
        return;
      case 'QuizMotivate':
        final feedback =
            _currentQuestion['feedback'] as Map<String, dynamic>? ?? const {};
        final motivate = feedback['motivate_next'] as Map<String, dynamic>?;
        if (motivate != null) {
          _addBot(
            _resolveText(motivate['display_text'] as String? ?? 'Keep going!'),
          );
        }
        _quizIndex++;
        _enterStep('AF-QUIZ-QUESTION');
        return;
      case 'SubmissionReview':
        _addBot('Your submission is reviewed. You did a great job champion!');
        _enterStep('AF-013');
        return;
      case 'ScoreSummary':
        child = _ScoreSummaryCard(
          videoPoints: _videoPoints,
          submissionPoints: _submissionPoints,
          quizScore: _quizScore,
          onContinue: () => _enterStep(step['next_step'] as String?),
        );
        break;
      case 'UnitPreviewCard':
        child = _UnitPreviewCard(
          unit: _nextUnit,
          onStart: _startNextUnit,
          onLater: () => _enterStep('AF-END'),
        );
        break;
      default:
        child = _SimpleCard(
          text: step['fallback_guide'] as String? ?? component,
        );
    }

    _messages.add(
      ActivityMessage(
        id: '${step['step_id']}_${_messages.length}',
        child: child,
      ),
    );
    setState(() {});
    _scrollToBottom();
  }

  void _completeVideo() {
    _addUser('Watch complete');
    _progress['video_done'] = true;
    _progress['step_id'] = 'AF-005';
    ref.read(learningDashboardProvider.notifier).completeVideo();
    _enterStep('AF-005');
  }

  void _submitProject(String value) {
    _addUser(value);
    _progress['submission_done'] = true;
    _progress['submission_value'] = value;
    _progress['step_id'] = 'AF-008';
    ref.read(learningDashboardProvider.notifier).submitProject();
    _enterStep('AF-008');
  }

  void _answerQuiz(String optionId) {
    final correct = optionId == _currentQuestion['correct_option_id'];
    final option = (_currentQuestion['options'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .firstWhere(
          (opt) => opt['option_id'] == optionId,
          orElse: () => {'text': optionId},
        );
    _addUser(option['text'] as String? ?? optionId);

    if (correct) {
      _quizScore++;
      _enterStep('AF-QUIZ-CORRECT');
    } else {
      _enterStep('AF-QUIZ-WRONG');
    }
  }

  void _nextQuizQuestion() {
    if (_isLastQuestion) {
      _enterStep('AF-011');
      return;
    }
    _quizIndex++;
    _enterStep('AF-QUIZ-QUESTION');
  }

  void _addBot(String text) {
    if (text.trim().isEmpty) return;
    _messages.add(ActivityMessage(id: 'bot_${_messages.length}', text: text));
  }

  void _addUser(String text) {
    _messages.add(
      ActivityMessage(id: 'user_${_messages.length}', text: text, isUser: true),
    );
    setState(() {});
    _scrollToBottom();
  }

  String _resolveText(String value) {
    return value
        .replaceAll('{{name}}', 'Aarav')
        .replaceAll('{{unit_name}}', _unit?['unit_name'] as String? ?? '')
        .replaceAll(
          '{{course_display}}',
          _course?['course_display'] as String? ?? '',
        )
        .replaceAll(
          '{{video_description}}',
          ((_unit?['video'] as Map<String, dynamic>?)?['description']
                  as String?) ??
              '',
        )
        .replaceAll('{{video_points}}', '$_videoPoints')
        .replaceAll('{{submission_points}}', '$_submissionPoints')
        .replaceAll('{{quiz_question_count}}', '${_questions.length}')
        .replaceAll('{{part_of_day}}', 'day');
  }

  String _buttonLabelFor(String stepId) {
    return switch (stepId) {
      'AF-003' => 'Watch',
      'AF-013' => 'Yes yes yes! 🙌🙌🙌',
      'AF-015' => 'Continue',
      _ => 'Continue',
    };
  }

  List<dynamic> get _questions {
    final quiz = _unit?['quiz'] as Map<String, dynamic>? ?? const {};
    return quiz['questions'] as List<dynamic>? ?? const [];
  }

  Map<String, dynamic> get _currentQuestion {
    if (_questions.isEmpty) return const {};
    final safeIndex = _quizIndex.clamp(0, _questions.length - 1).toInt();
    return _questions[safeIndex] as Map<String, dynamic>;
  }

  Map<String, dynamic> _currentQuestionFeedback(String key) {
    final feedback =
        _currentQuestion['feedback'] as Map<String, dynamic>? ?? const {};
    return feedback[key] as Map<String, dynamic>? ?? const {};
  }

  bool get _isLastQuestion => _quizIndex >= _questions.length - 1;
  List<dynamic> get _units => _course?['units'] as List<dynamic>? ?? const [];
  Map<String, dynamic>? get _nextUnit {
    final nextIndex = _unitIndex + 1;
    if (nextIndex >= _units.length) return null;
    return _units[nextIndex] as Map<String, dynamic>;
  }

  Future<void> _startNextUnit() async {
    final next = _nextUnit;
    if (next == null) {
      _enterStep('AF-END');
      return;
    }
    setState(() {
      _unitIndex++;
      _unit = next;
      _quizIndex = 0;
      _quizScore = 0;
      _progress = {
        'unit_index': _unitIndex,
        'step_id': 'AF-001',
        'quiz_index': 0,
        'quiz_score': 0,
        'video_done': false,
        'submission_done': false,
        'quiz_done': false,
      };
    });
    await _save();
    ref.invalidate(learningDashboardProvider);
    _enterStep('AF-001', replace: true);
  }

  int get _videoPoints =>
      (_unit?['video'] as Map<String, dynamic>?)?['points'] as int? ?? 0;
  int get _submissionPoints =>
      (_unit?['submission'] as Map<String, dynamic>?)?['points'] as int? ?? 0;
  int get _totalPoints => _videoPoints + _submissionPoints + _quizScore;

  @override
  Widget build(BuildContext context) {
    final unitName =
        _unit?['unit_name'] as String? ?? 'Get Ready for ScratchJr';

    return AppNav(
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.buttonColor),
              )
            : Column(
                children: [
                  _ActivityHeader(
                    title: unitName == 'States of Matter'
                        ? 'Get Ready for ScratchJr'
                        : unitName,
                    points: _totalPoints,
                    onBack: () => context.go(AppRoutes.home),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) =>
                              _ActivityBubble(message: _messages[index]),
                        ),
                      ),
                    ),
                  ),
                  _InputBar(controller: _inputController, onSend: _addUser),
                ],
              ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  final String title;
  final int points;
  final VoidCallback onBack;

  const _ActivityHeader({
    required this.title,
    required this.points,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final openBuddy = TapBuddyScope.maybeOpenOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final showLogos = constraints.maxWidth >= 560;

        return Container(
          height: compact ? 76 : 86,
          color: Colors.white,
          child: Row(
            children: [
              SizedBox(
                width: compact ? 72 : 140,
                child: IconButton(
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_circle_left_outlined,
                    size: compact ? 42 : 48,
                  ),
                  color: const Color(0xFF6E6E7A),
                ),
              ),
              const VerticalDivider(width: 1, color: Color(0xFFD9DAE4)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
                  child: Text(
                    title,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: compact ? 17 : 22,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6E6E7A),
                    ),
                  ),
                ),
              ),
              _PointPill(points: points),
              SizedBox(width: compact ? 8 : 14),
              OutlinedButton(
                onPressed: openBuddy,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.buttonColor,
                  side: const BorderSide(color: AppTheme.buttonColor),
                  minimumSize: Size(compact ? 44 : 0, 36),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 16,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: compact
                    ? const Icon(Icons.chat_bubble_outline_rounded, size: 18)
                    : const Text('Ask TAP Buddy'),
              ),
              if (showLogos) ...[
                SizedBox(width: compact ? 10 : 24),
                Image.asset('assets/logos/gov-logo.png', height: 30),
                const SizedBox(width: 10),
                Image.asset('assets/logos/tap-otherLogo.png', height: 30),
              ],
              SizedBox(width: compact ? 12 : 28),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityStartCard extends StatelessWidget {
  final String text;
  final VoidCallback onWatch;

  const _ActivityStartCard({required this.text, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 38),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/class-screen/Timer.png',
              width: 210,
              height: 210,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E4FA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.volume_up_rounded,
                    size: 16,
                    color: AppTheme.buttonColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hear again',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.buttonColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1C1C21),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 56,
              child: ElevatedButton(
                onPressed: onWatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Watch'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionStartCard extends StatelessWidget {
  final String text;
  final String buttonLabel;
  final VoidCallback onStart;

  const _SectionStartCard({
    required this.text,
    required this.buttonLabel,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/class-screen/Timer.png',
              width: 190,
              height: 190,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E4FA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.volume_up_rounded,
                    size: 16,
                    color: AppTheme.buttonColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hear again',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.buttonColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  height: 1.28,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1C1C21),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 270,
              height: 56,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityBubble extends StatelessWidget {
  final ActivityMessage message;

  const _ActivityBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.child != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Align(
          alignment:
              message.id == 'activity_start' ||
                  message.id == 'section_start' ||
                  message.id.startsWith('AF-014')
              ? Alignment.center
              : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  message.id == 'activity_start' ||
                      message.id == 'section_start'
                  ? 820
                  : 620,
            ),
            child: message.child!,
          ),
        ),
      );
    }

    if (message.actions.isNotEmpty &&
        (message.text == null || message.text!.isEmpty)) {
      return _Actions(actions: message.actions);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: message.isUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFFE0F2E6)
                    : const Color(0xFFEFEFF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.text ?? '',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.35,
                  color: const Color(0xFF1C1C21),
                ),
              ),
            ),
          ),
          if (message.actions.isNotEmpty) _Actions(actions: message.actions),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final List<ActivityAction> actions;

  const _Actions({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (actions.length > 1) {
            return Column(
              children: [
                for (final action in actions) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: _ActionButton(action: action),
                  ),
                  if (action != actions.last) const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final action in actions)
                SizedBox(height: 42, child: _ActionButton(action: action)),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final ActivityAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: action.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.buttonColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        action.label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TextField(
                  controller: controller,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.add_rounded, size: 20),
                    suffixIcon: const Icon(Icons.mood_rounded, size: 18),
                    hintText: 'Type here...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF8E8E9F),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _submit(controller.text),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppTheme.buttonColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(String text) {
    if (text.trim().isEmpty) return;
    onSend(text.trim());
    controller.clear();
  }
}

class _PointPill extends StatelessWidget {
  final int points;

  const _PointPill({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE1E2EA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, size: 16, color: Color(0xFFE29A22)),
          const SizedBox(width: 6),
          Text(
            '$points',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ScoreSummaryCard extends StatelessWidget {
  final int videoPoints;
  final int submissionPoints;
  final int quizScore;
  final VoidCallback onContinue;

  const _ScoreSummaryCard({
    required this.videoPoints,
    required this.submissionPoints,
    required this.quizScore,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final total = videoPoints + submissionPoints + quizScore;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 388),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFEFF4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AspectRatio(
              aspectRatio: 1.06,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        flex: 48,
                        child: Container(color: const Color(0xFFFFE614)),
                      ),
                      Expanded(
                        flex: 52,
                        child: Container(color: const Color(0xFF82E3EA)),
                      ),
                    ],
                  ),
                  Positioned.fill(
                    top: 12,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        'YOU WON',
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF143B40),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Icon(
                      Icons.volume_up_rounded,
                      color: AppTheme.buttonColor,
                      size: 18,
                    ),
                  ),
                  Positioned(
                    top: 56,
                    left: 124,
                    right: 96,
                    child: Image.asset(
                      'assets/class-screen/Skill Passport 1.png',
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: 52,
                    right: 46,
                    bottom: 30,
                    child: Column(
                      children: [
                        _ScoreLine(
                          label: 'Activity Points',
                          value: '$videoPoints',
                        ),
                        _ScoreLine(label: 'Quiz Points', value: '$quizScore'),
                        const _ScoreLine(label: 'Special Gems', value: '1'),
                        _ScoreLine(
                          label: 'Submission Streaks',
                          value: '$submissionPoints',
                          red: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue • $total pts',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final String label;
  final String value;
  final bool red;

  const _ScoreLine({
    required this.label,
    required this.value,
    this.red = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF143B40),
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _DottedLinePainter(),
              child: const SizedBox(height: 1),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: red ? const Color(0xFFE30D10) : const Color(0xFF0E5B73),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  red
                      ? Icons.local_fire_department_rounded
                      : Icons.stars_rounded,
                  size: 12,
                  color: red
                      ? const Color(0xFFFFD45A)
                      : const Color(0xFFF4AC38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF143B40)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, 0), Offset(x + 2, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnitPreviewCard extends StatelessWidget {
  final Map<String, dynamic>? unit;
  final VoidCallback onStart;
  final VoidCallback onLater;

  const _UnitPreviewCard({
    required this.unit,
    required this.onStart,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    if (unit == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFF4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "You're all caught up for now. New activities will appear here when your course has more units.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onLater,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Finish for today'),
              ),
            ),
          ],
        ),
      );
    }

    final video = unit!['video'] as Map<String, dynamic>? ?? const {};
    final title = unit!['unit_name'] as String? ?? 'Next activity';
    final points = video['points'] as int? ?? 0;

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          final preview = Container(
            height: compact ? 150 : 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE1E2EA), width: 6),
            ),
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                size: 34,
                color: Color(0xFFB9BBC8),
              ),
            ),
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Core Basic ${(unit!['unit_index'] as int? ?? 0) + 1}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF777887),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: compact ? 20 : 22,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1C1C21),
                ),
              ),
              const SizedBox(height: 16),
              _PreviewReward(
                label: '$points Points',
                color: const Color(0xFFF4AC38),
              ),
              const SizedBox(height: 8),
              const _PreviewReward(label: '1 streak', color: Color(0xFF24A866)),
              const SizedBox(height: 8),
              const _PreviewReward(
                label: '1 skill gem',
                color: AppTheme.buttonColor,
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Watch another video?',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1C1C21),
                      ),
                    ),
                    const SizedBox(width: 26),
                    const Icon(
                      Icons.volume_up_rounded,
                      size: 16,
                      color: AppTheme.buttonColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCDDE7)),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          preview,
                          const SizedBox(height: 16),
                          details,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: preview),
                          const SizedBox(width: 24),
                          Expanded(child: details),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: onStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.buttonColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Let's go 🚀"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: onLater,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5E4FA),
                          foregroundColor: AppTheme.buttonColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Maybe later'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewReward extends StatelessWidget {
  final String label;
  final Color color;

  const _PreviewReward({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hexagon_rounded, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6E6E7A),
          ),
        ),
      ],
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final String text;

  const _SimpleCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 18,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

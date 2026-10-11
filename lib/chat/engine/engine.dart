import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/chat/action/action.dart';
import 'package:tapapp/chat/audio/audio.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/registry/registry.dart';
import 'package:tapapp/chat/resolve/resolve.dart';
import 'package:tapapp/chat/submission/submission.dart';
import 'package:tapapp/core/flow/flow.dart';

class ChatSessionKey {
  const ChatSessionKey({
    required this.profileId,
    required this.surface,
    required this.category,
    required this.fileName,
    required this.entryStepId,
    required this.languageCode,
  });

  final String profileId;
  final String surface;
  final String category;
  final String fileName;
  final String entryStepId;
  final String languageCode;

  @override
  bool operator ==(Object other) =>
      other is ChatSessionKey &&
      other.profileId == profileId &&
      other.surface == surface &&
      other.category == category &&
      other.fileName == fileName &&
      other.entryStepId == entryStepId &&
      other.languageCode == languageCode;

  @override
  int get hashCode => Object.hash(
    profileId,
    surface,
    category,
    fileName,
    entryStepId,
    languageCode,
  );
}

typedef CrossFlowTarget = ({
  String category,
  String fileName,
  String entryStepId,
});

class ChatQuizFeedback {
  const ChatQuizFeedback({
    required this.isCorrect,
    required this.points,
    this.correctAnswerLabel,
  });

  final bool isCorrect;
  final int points;
  final String? correctAnswerLabel;
}

class ChatSessionDeps {
  const ChatSessionDeps({
    required this.actionHandler,
    required this.templateContext,
    this.contentSource,
    this.submissionContentFetcher,
  });

  final ChatActionHandler actionHandler;
  final TemplateContext templateContext;
  final ChatContentSource? contentSource;
  final SubmissionContentFetcher? submissionContentFetcher;
}

class ChatSessionDepsRegistry {
  ChatSessionDepsRegistry._();

  static final Map<ChatSessionKey, ChatSessionDeps> _deps = {};

  static void register(ChatSessionKey key, ChatSessionDeps deps) {
    _deps[key] = deps;
  }

  static void unregister(ChatSessionKey key) {
    _deps.remove(key);
  }

  static ChatSessionDeps? lookup(ChatSessionKey key) => _deps[key];
}

class ChatSession {
  ChatSession({
    required this.key,
    required this.flow,
    required this.deps,
  }) {
    _crossFlowController = StreamController<CrossFlowTarget>.broadcast();
  }

  final ChatSessionKey key;
  final Map<String, FlowNode> flow;
  final ChatSessionDeps deps;

  final List<ChatItem> _items = [];
  final List<String> _history = [];
  final ChatVariables _variables = ChatVariables();
  final List<Timer> _timers = [];

  late final StreamController<CrossFlowTarget> _crossFlowController;
  Stream<CrossFlowTarget> get crossFlowTarget => _crossFlowController.stream;

  String? _currentStepId;
  bool _awaitingInput = true;
  bool _disposed = false;
  bool _failed = false;
  String? _errorMessage;
  int _seq = 0;
  ChatQuizFeedback? _lastFeedback;

  bool get ready => _currentStepId != null || _failed;
  bool get failed => _failed;
  String? get errorMessage => _errorMessage;
  List<ChatItem> get items => List.unmodifiable(_items);
  bool get isAwaitingInput => _awaitingInput;
  bool get canGoBack => _history.length > 1;
  ChatQuizFeedback? get lastFeedback => _lastFeedback;
  ChatVariables get variables => _variables;

  void Function()? onChanged;

  String _nextId(String prefix) => '$prefix:${_seq++}';

  Future<void> start() async {
    await _enter(key.entryStepId);
  }

  Future<void> goBack() async {
    if (_history.length <= 1) return;
    final previousStepId = _findPreviousBackTarget();
    if (previousStepId == null) return;
    _history.removeLast();
    while (_history.isNotEmpty && _history.last != previousStepId) {
      _history.removeLast();
    }
    await _enter(previousStepId, recordHistory: _history.isEmpty);
  }

  String? _findPreviousBackTarget() {
    final currentStepId = _currentStepId;
    if (currentStepId == null) return null;
    final node = flow[currentStepId];
    final declaredBack = node?.data['back_step'];
    if (declaredBack is String && declaredBack.isNotEmpty) {
      return declaredBack;
    }
    if (_history.length >= 2) {
      return _history[_history.length - 2];
    }
    return null;
  }

  Future<void> _enter(String stepId, {bool recordHistory = true}) async {
    if (_disposed) return;
    final node = flow[stepId];
    if (node == null) {
      _failed = true;
      _errorMessage = 'Step "$stepId" was not found.';
      _emit();
      return;
    }

    _currentStepId = stepId;
    if (recordHistory) _history.add(stepId);
    _awaitingInput = false;

    if (node.type == 'action') {
      await _runActionStep(node);
      return;
    }

    ChatItem item;
    final contentSource = deps.contentSource;
    ChatItem? bound;
    if (contentSource != null && ChatItemBuilder.needsBinding(node)) {
      bound = await contentSource.bind(
        node,
        ChatBindContext(id: _nextId(stepId), variables: _variables),
      );
    }

    if (bound != null) {
      item = bound;
    } else {
      item = ChatItemBuilder.fromFlowNode(
        node,
        deps.templateContext,
        id: _nextId(stepId),
        vars: _variables.toMap(),
      );
    }

    final split = ChatItemBuilder.split(node, item, () => _nextId(stepId));
    _items.addAll(split);

    _awaitingInput = true;
    _emit();

    if (node.autoAdvanceMs != null) {
      _schedule(node.autoAdvanceMs!, stepId);
    } else if (_isNonInteractive(node)) {
      _schedule(0, stepId);
    }
  }

  bool _isNonInteractive(FlowNode node) {
    if (node.options.isNotEmpty) return false;
    if (node.nextRule != null) return false;
    if (node.nextStep == null || node.nextStep!.isEmpty) return false;
    final kind = ChatItemBuilder.kindFor(node);
    const interactiveKinds = {
      ChatItemKind.choice,
      ChatItemKind.form,
      ChatItemKind.submission,
      ChatItemKind.quiz,
      ChatItemKind.checkpoint,
      ChatItemKind.profileVerify,
    };
    return !interactiveKinds.contains(kind);
  }

  Future<void> _runActionStep(FlowNode node) async {
    final actionName = node.data['action']?.toString();
    final action = _resolveAction(actionName);
    if (action == null) {
      _failed = true;
      _errorMessage = 'Unknown action "$actionName" for step "${node.stepId}".';
      _emit();
      return;
    }

    final result = await deps.actionHandler.handle(
      action,
      data: {'stepId': node.stepId, ..._variables.toMap()},
    );

    if (!result.success) {
      _items.add(
        ChatItemBuilder.error(
          id: _nextId('error'),
          stepId: node.stepId,
          message: result.errorMessage ?? 'Something went wrong.',
          retryAction: node.stepId,
        ),
      );
      _awaitingInput = true;
      _emit();
      return;
    }

    final payload = result.payload;
    if (payload != null) _variables.addAll(payload);

    final next = node.nextStep;
    if (next != null && next.isNotEmpty) {
      await _enter(next);
    } else {
      _awaitingInput = true;
      _emit();
    }
  }

  ChatAction? _resolveAction(String? actionName) {
    for (final candidate in ChatAction.values) {
      if (candidate.name == actionName) return candidate;
    }
    return null;
  }

  void _schedule(int ms, String stepId) {
    final timer = Timer(Duration(milliseconds: ms), () {
      if (_disposed || _currentStepId != stepId) return;
      _advance(node: flow[stepId]);
    });
    _timers.add(timer);
  }

  void _advance({FlowNode? node, String? target}) {
    final next = target ?? node?.nextStep;
    if (next == null || next.isEmpty) return;
    if (next == 'activity_flow' || next.startsWith('AF-')) {
      _crossFlowController.add((
        category: 'activity',
        fileName: 'activity_flow.json',
        entryStepId: next,
      ));
      return;
    }
    unawaited(_enter(next));
  }

  Future<void> onOptionSelected(String stepId, String optionKey) async {
    final node = flow[stepId];
    if (node == null) return;
    _awaitingInput = false;

    if (node.type == 'quiz' || node.component == 'QuizQuestion') {
      final isCorrect = optionKey == 'correct';
      _lastFeedback = ChatQuizFeedback(
        isCorrect: isCorrect,
        points: isCorrect ? kClassroomQuizPointsPerCorrectAnswer : 0,
      );
    }

    final selectedLabel = _optionLabelFor(node, optionKey);
    await _recordSelection(node, optionKey, selectedLabel);

    final rule = node.nextRule;
    String? next = node.nextStep;
    if (rule != null) {
      if (rule['when'] == 'answer') {
        next = optionKey == 'correct' ? rule['correct'] as String? : rule['wrong'] as String?;
      } else if (rule['when'] == 'choice') {
        final options = rule['options'];
        if (options is Map) next = options[optionKey] as String?;
      }
    }
    _advance(node: node, target: next);
  }

  String? _optionLabelFor(FlowNode node, String optionKey) {
    for (final option in node.options) {
      if (option.key == optionKey) return option.label;
    }
    return null;
  }

  Future<void> _recordSelection(
    FlowNode node,
    String optionKey,
    String? optionLabel,
  ) async {
    final cacheFields = node.data['cache_fields'];
    if (cacheFields is! List || cacheFields.isEmpty) return;

    for (final field in cacheFields) {
      _variables[field.toString()] = optionKey;
      if (optionLabel != null) {
        _variables['${field.toString()}_display'] = optionLabel;
      }
    }

    final handlerAction = node.data['on_select_action'];
    if (handlerAction is String && handlerAction.isNotEmpty) {
      final action = _resolveAction(handlerAction);
      if (action != null) {
        final result = await deps.actionHandler.handle(
          action,
          data: {
            'stepId': node.stepId,
            'optionKey': optionKey,
            ..._variables.toMap(),
          },
        );
        if (result.success && result.payload != null) {
          _variables.addAll(result.payload!);
        }
      }
    }
  }

  Future<void> onSubmissionAnswer(String stepId, Object answer) async {
    final node = flow[stepId];
    if (node == null) return;
    _awaitingInput = false;

    if (node.type == 'static' &&
        answer is Map &&
        node.data['cache_fields'] is List) {
      final values = answer['values'] ?? answer;
      if (values is Map) {
        final cacheFields = node.data['cache_fields'] as List;
        for (final field in cacheFields) {
          final key = field.toString();
          if (values.containsKey(key)) {
            _variables[key] = values[key];
          }
        }
      }
      final saveAction = node.data['on_submit_action'];
      if (saveAction is String && saveAction.isNotEmpty) {
        final action = _resolveAction(saveAction);
        if (action != null) {
          await deps.actionHandler.handle(
            action,
            data: {'stepId': node.stepId, 'values': values},
          );
        }
      }
    }

    _advance(node: node);
  }

  Future<void> onRetry(String? retryAction) async {
    if (retryAction == null) return;
    await _enter(retryAction);
  }

  Future<void> onAction(ChatAction action, {Map<String, Object?>? data}) async {
    final result = await deps.actionHandler.handle(action, data: data);
    if (!result.success) {
      final stepId = _currentStepId;
      if (stepId != null) {
        _items.add(
          ChatItemBuilder.error(
            id: _nextId('error'),
            stepId: stepId,
            message: result.errorMessage ?? 'Something went wrong.',
          ),
        );
        _emit();
      }
      return;
    }

    if (result.payload != null) _variables.addAll(result.payload!);

    final node = _currentStepId == null ? null : flow[_currentStepId!];
    if (node != null) _advance(node: node);
  }

  void _emit() {
    if (_disposed) return;
    onChanged?.call();
  }

  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    unawaited(_crossFlowController.close());
  }
}

class ChatSessionState {
  const ChatSessionState({
    required this.ready,
    required this.failed,
    required this.errorMessage,
    required this.items,
    required this.isAwaitingInput,
    required this.lastFeedback,
  });

  final bool ready;
  final bool failed;
  final String? errorMessage;
  final List<ChatItem> items;
  final bool isAwaitingInput;
  final ChatQuizFeedback? lastFeedback;

  factory ChatSessionState.loading() => const ChatSessionState(
    ready: false,
    failed: false,
    errorMessage: null,
    items: [],
    isAwaitingInput: false,
    lastFeedback: null,
  );

  factory ChatSessionState.fromSession(ChatSession session) => ChatSessionState(
    ready: session.ready,
    failed: session.failed,
    errorMessage: session.errorMessage,
    items: session.items,
    isAwaitingInput: session.isAwaitingInput,
    lastFeedback: session.lastFeedback,
  );
}

class ChatSessionNotifier extends StateNotifier<ChatSessionState> {
  ChatSessionNotifier(this.ref, this.key) : super(ChatSessionState.loading()) {
    _initialize();
  }

  final Ref ref;
  final ChatSessionKey key;
  ChatSession? session;

  Future<void> _initialize() async {
    final deps = ChatSessionDepsRegistry.lookup(key);
    if (deps == null) {
      state = const ChatSessionState(
        ready: false,
        failed: true,
        errorMessage: 'Chat session dependencies were not registered.',
        items: [],
        isAwaitingInput: false,
        lastFeedback: null,
      );
      return;
    }

    try {
      final flowRepository = await ref.read(flowRepositoryProvider.future);
      final resolved = await flowRepository.loadFlow(
        category: key.category,
        fileName: key.fileName,
        languageCode: key.languageCode,
      );
      final graph = FlowResolver.parse(resolved.data);

      final newSession = ChatSession(key: key, flow: graph.steps, deps: deps);
      newSession.onChanged = () {
        if (!mounted) return;
        state = ChatSessionState.fromSession(newSession);
      };
      session = newSession;
      await newSession.start();
      if (!mounted) return;
      state = ChatSessionState.fromSession(newSession);
    } catch (error) {
      if (!mounted) return;
      state = ChatSessionState(
        ready: false,
        failed: true,
        errorMessage: error.toString(),
        items: const [],
        isAwaitingInput: false,
        lastFeedback: null,
      );
    }
  }

  ChatRenderContext renderContext({
    String studentName = 'Champ',
    String courseDisplay = '',
  }) {
    final currentSession = session;
    return ChatRenderContext(
      onAction: (action, {data}) {
        unawaited(currentSession?.onAction(action, data: data));
      },
      onOptionSelected: (stepId, optionKey) {
        unawaited(currentSession?.onOptionSelected(stepId, optionKey));
      },
      onSubmissionAnswer: (stepId, answer) {
        unawaited(currentSession?.onSubmissionAnswer(stepId, answer));
      },
      onRetry: (retryAction) {
        unawaited(currentSession?.onRetry(retryAction));
      },
      onCheckpoint: (item) {
        unawaited(currentSession?.onAction(
          ChatAction.continueFlow,
          data: {'stepId': item.stepId, 'checkpointAction': item.action},
        ));
      },
      audioController: ChatAudioPlaybackController(),
      submissionContentFetcher: currentSession?.deps.submissionContentFetcher,
      studentName: studentName,
      courseDisplay: courseDisplay,
      isAwaitingInput: state.isAwaitingInput,
    );
  }

  void goBack() {
    unawaited(session?.goBack());
  }

  @override
  void dispose() {
    session?.dispose();
    super.dispose();
  }
}

final chatSessionProvider = StateNotifierProvider.autoDispose
    .family<ChatSessionNotifier, ChatSessionState, ChatSessionKey>(
  (ref, key) => ChatSessionNotifier(ref, key),
);
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tapapp/chat/chat.dart';
import 'package:tapapp/core/learner/learner.dart';
import 'package:tapapp/core/profile/profile.dart';
import 'package:tapapp/core/router/router.dart';
import 'package:tapapp/core/theme/theme.dart';
import 'package:tapapp/features/classroom/classroom.dart';
import 'package:tapapp/features/classroom/presentation/widgets/states/loading_skeleton.dart';
import 'package:tapapp/features/classroom/reveal/reveal.dart';
import 'package:tapapp/features/home/home.dart';
import 'package:tapapp/shared/widgets/app_header.dart';

class ClassScreen extends ConsumerStatefulWidget {
  const ClassScreen({super.key});

  @override
  ConsumerState<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends ConsumerState<ClassScreen> {
  int _attempt = 0;

  Future<void> _startNextActivity() async {
    final profile = await ref.read(activeProfileProvider.future);
    if (profile == null) return;
    final repository = await ref.read(learnerStateRepositoryProvider.future);
    await repository.clearHomeCelebration(profile.learnerId);
    ref.invalidate(learningDashboardProvider);
    ref.invalidate(classSessionBootstrapProvider);
    if (!mounted) return;
    setState(() => _attempt++);
  }

  void _goHome() => context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(learningDashboardProvider);

    return dashboardAsync.when(
      loading: () => _scaffold(const ClassLoadingSkeleton()),
      error: (_, _) => _buildClassSession(),
      data: (dashboard) {
        if (dashboard.hasReachedWeeklyCap) {
          return _scaffold(
            ClassWeeklyCapRevealBody(unitIndex: 0, onHome: _goHome),
          );
        }
        if (dashboard.showCompletionCelebration && dashboard.unit != null) {
          return _scaffold(
            ClassPendingActivityChoiceBody(
              unit: dashboard.unit!,
              onStart: _startNextActivity,
              onMaybeLater: _goHome,
            ),
          );
        }
        return _buildClassSession();
      },
    );
  }

  Widget _buildClassSession() {
    final depsAsync = ref.watch(classroomChatDepsProvider(_attempt));

    return _scaffold(
      depsAsync.when(
        loading: () => const ClassLoadingSkeleton(),
        error: (error, _) {
          if (error is NoUnitAvailableException) {
            return ClassWeeklyCapRevealBody(unitIndex: 0, onHome: _goHome);
          }
          return _ErrorBody(error: error, onBack: _goHome);
        },
        data: (deps) => _ClassChatView(
          key: ValueKey('classroom_session_$_attempt'),
          deps: deps,
          onStartNextActivity: _startNextActivity,
        ),
      ),
    );
  }

  Widget _scaffold(Widget body) => Scaffold(
    backgroundColor: AppTheme.appBackground,
    body: SafeArea(bottom: false, child: body),
  );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onBack});

  final Object error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    final isNoEnrollment = error is NoActiveEnrollmentException;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.all(scale.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNoEnrollment
                    ? "You're not enrolled in a course yet."
                    : 'Something went wrong loading your class.',
                textAlign: TextAlign.center,
                style: AppTheme.text(size: 18, weight: FontWeight.w700),
              ),
              SizedBox(height: scale.xl),
              SizedBox(
                height: scale.buttonHeight,
                child: ElevatedButton(
                  onPressed: onBack,
                  style: AppTheme.primaryButtonStyle(),
                  child: const Text('Go home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassChatView extends ConsumerStatefulWidget {
  const _ClassChatView({
    super.key,
    required this.deps,
    required this.onStartNextActivity,
  });

  final ClassroomChatDeps deps;
  final VoidCallback onStartNextActivity;

  @override
  ConsumerState<_ClassChatView> createState() => _ClassChatViewState();
}

class _ClassChatViewState extends ConsumerState<_ClassChatView> {
  OverlayEntry? _toastOverlay;
  Timer? _toastTimer;
  late final ChatSessionKey _sessionKey;
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _sessionKey = widget.deps.key;
    final superseded = ChatSessionDepsRegistry.lookup(_sessionKey) != null;
    ChatSessionDepsRegistry.register(
      _sessionKey,
      ChatSessionDeps(
        actionHandler: widget.deps.handler,
        templateContext: widget.deps.templateContext,
        contentSource: widget.deps.contentSource,
      ),
    );
    if (superseded) {
      final container = _container;
      final key = _sessionKey;
      Future.microtask(() => container.invalidate(chatSessionProvider(key)));
    }
    widget.deps.handler.addListener(_onHandlerChanged);
  }

  @override
  void dispose() {
    widget.deps.handler.removeListener(_onHandlerChanged);
    final registered = ChatSessionDepsRegistry.lookup(_sessionKey);
    if (registered != null &&
        identical(registered.actionHandler, widget.deps.handler)) {
      ChatSessionDepsRegistry.unregister(_sessionKey);
      final container = _container;
      final key = _sessionKey;
      Future.microtask(() => container.invalidate(chatSessionProvider(key)));
    }
    _removeToast();
    super.dispose();
  }

  void _onHandlerChanged() {
    if (mounted) setState(() {});
  }

  void _goHome() {
    ref.invalidate(learnerStateDataProvider(widget.deps.learnerId));
    context.go(AppRoutes.home);
  }

  Future<void> _onFooterAction(ChatAction action) async {
    await widget.deps.handler.handle(action);
    if (!mounted) return;
    switch (action) {
      case ChatAction.watchAnother:
        widget.onStartNextActivity();
      case ChatAction.maybeLater:
      case ChatAction.openHome:
        _goHome();
      default:
        break;
    }
  }

  NextActivityItem _nextActivityItem() {
    final next = widget.deps.nextUnit;
    return NextActivityItem(
      id: 'next_activity',
      stepId: 'NEXT-ACTIVITY',
      courseDisplay: widget.deps.courseDisplay,
      unitName: next?.name ?? widget.deps.unit.name,
      points: next?.xp ?? 0,
      streak: 1,
      gems: 1,
      hasNextUnit: next != null,
    );
  }

  void _showQuizToast(ChatQuizFeedback feedback) {
    if (!mounted) return;
    _removeToast();

    final media = MediaQuery.of(context);
    final scale = AppSpacing.of(context);
    final isWide = scale.showsSideRail;
    final message = feedback.isCorrect
        ? 'Correct Answer!  +${feedback.points} points'
        : 'Not quite. Correct answer: ${feedback.correctAnswerLabel ?? ''}';

    _toastOverlay = OverlayEntry(
      builder: (_) => Positioned(
        top: media.padding.top + (isWide ? scale.section + scale.md : scale.sm),
        right: isWide ? scale.xl : scale.sm,
        left: isWide ? null : scale.sm,
        width: isWide ? 340 : null,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: scale.lg,
                vertical: scale.md,
              ),
              decoration: BoxDecoration(
                color: feedback.isCorrect
                    ? AppTheme.successToast
                    : AppTheme.errorToast,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.floatingShadow,
              ),
              child: Row(
                children: [
                  Text(
                    feedback.isCorrect ? '🎉' : '💡',
                    style: const TextStyle(fontSize: 20),
                  ),
                  SizedBox(width: scale.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: AppTheme.text(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppTheme.toastText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_toastOverlay!);
    _toastTimer = Timer(
      Duration(milliseconds: feedback.isCorrect ? 1400 : 2300),
      _removeToast,
    );
  }

  void _removeToast() {
    _toastTimer?.cancel();
    _toastTimer = null;
    _toastOverlay?.remove();
    _toastOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final handler = widget.deps.handler;
    final sessionKey = _sessionKey;

    ref.listen<ChatSessionState>(chatSessionProvider(sessionKey), (
      previous,
      next,
    ) {
      final feedback = next.lastFeedback;
      if (feedback == null || identical(feedback, previous?.lastFeedback)) {
        return;
      }
      handler.recordQuizFeedback(feedback);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showQuizToast(feedback),
      );
    });

    if (handler.outcome == ClassSessionOutcome.weeklyCapReached) {
      return ClassWeeklyCapRevealBody(
        unitIndex: widget.deps.unitIndex,
        onHome: _goHome,
      );
    }

    final sessionState = ref.watch(chatSessionProvider(sessionKey));
    if (sessionState.failed) {
      return _ErrorBody(
        error: sessionState.errorMessage ?? 'Chat failed to load.',
        onBack: _goHome,
      );
    }
    if (!sessionState.ready) return const ClassLoadingSkeleton();

    final notifier = ref.read(chatSessionProvider(sessionKey).notifier);
    final ctx = notifier.renderContext(
      studentName: widget.deps.studentName,
      courseDisplay: widget.deps.courseDisplay,
    );

    final items = sessionState.items;
    final first = items.isEmpty ? null : items.first;
    final isVideoStart =
        items.length == 1 && first is CheckpointItem && first.action == 'video';
    final showChoice = handler.outcome == ClassSessionOutcome.choice;
    final revealProgress = showChoice ? 1.0 : handler.revealProgress;

    final footer = showChoice
        ? ChatItemRowFooter(
            child: NextActivityBlock(
              item: _nextActivityItem(),
              ctx: ctx.copyWith(
                onAction: (action, {data}) {
                  unawaited(_onFooterAction(action));
                },
              ),
            ),
          )
        : null;

    final chatList = ChatListView(
      items: items,
      renderContext: ctx,
      footer: footer,
    );

    return Column(
      children: [
        AppHeaderHome(
          title: handler.unitName,
          points: handler.displayedTotalPoints,
          showAskBuddy: true,
        ),
        Expanded(
          child: Container(
            color: AppTheme.appBackground,
            child: ChatLayout.resolve(
              context: context,
              mode: isVideoStart
                  ? ChatLayoutMode.centeredSingle
                  : ChatLayoutMode.columnWithRail,
              chatList: chatList,
              sideRail: ClassroomRevealSlot(
                unitIndex: widget.deps.unitIndex,
                revealProgress: revealProgress,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ChatItemRowFooter extends StatelessWidget {
  const ChatItemRowFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: scale.sm),
      child: child,
    );
  }
}
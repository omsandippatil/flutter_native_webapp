import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tapapp/core/router/app_router.dart';
import 'package:tapapp/core/theme/app_spacing.dart';
import 'package:tapapp/core/theme/app_theme.dart';
import 'package:tapapp/domain/learner/providers/learner_state_providers.dart';
import 'package:tapapp/domain/profile/providers/profile_providers.dart';
import 'package:tapapp/features/classroom/application/classroom_bootstrap_provider.dart';
import 'package:tapapp/features/classroom/application/classroom_providers.dart';
import 'package:tapapp/features/classroom/application/classroom_session_controller.dart';
import 'package:tapapp/features/classroom/models/classroom_message.dart';
import 'package:tapapp/features/classroom/presentation/widgets/chat/chat_bubble_row.dart';
import 'package:tapapp/features/classroom/presentation/widgets/chat/message_content.dart';
import 'package:tapapp/features/classroom/presentation/widgets/reveal/reveal_rail.dart';
import 'package:tapapp/features/classroom/presentation/widgets/states/loading_skeleton.dart';
import 'package:tapapp/features/home/providers/home_dashboard_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(learningDashboardProvider);

    return dashboardAsync.when(
      loading: () => _scaffold(const ClassLoadingSkeleton()),
      error: (_, _) => _buildClassSession(),
      data: (dashboard) {
        if (dashboard.hasReachedWeeklyCap) {
          return _scaffold(
            ClassWeeklyCapRevealBody(
              unitIndex: 0,
              onHome: () => context.go(AppRoutes.home),
            ),
          );
        }
        if (dashboard.showCompletionCelebration && dashboard.unit != null) {
          return _scaffold(
            ClassPendingActivityChoiceBody(
              unit: dashboard.unit!,
              onStart: _startNextActivity,
              onMaybeLater: () => context.go(AppRoutes.home),
            ),
          );
        }
        return _buildClassSession();
      },
    );
  }

  Widget _buildClassSession() {
    final controllerAsync = ref.watch(classChatControllerProvider(_attempt));

    return _scaffold(
      controllerAsync.when(
        loading: () => const ClassLoadingSkeleton(),
        error: (error, _) {
          if (error is NoUnitAvailableException) {
            return ClassWeeklyCapRevealBody(
              unitIndex: 0,
              onHome: () => context.go(AppRoutes.home),
            );
          }
          return _ErrorBody(
            error: error,
            onBack: () => context.go(AppRoutes.home),
          );
        },
        data: (controller) => _ClassChatView(
          controller: controller,
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
    required this.controller,
    required this.onStartNextActivity,
  });

  final ClassChatController controller;
  final VoidCallback onStartNextActivity;

  @override
  ConsumerState<_ClassChatView> createState() => _ClassChatViewState();
}

class _ClassChatViewState extends ConsumerState<_ClassChatView> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  int _lastQuizToastId = 0;
  OverlayEntry? _quizToastOverlay;
  Timer? _quizToastTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _ClassChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastMessageCount = 0;
      _lastQuizToastId = 0;
      _removeQuizToast();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _removeQuizToast();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final quizToast = widget.controller.quizToast;
    if (quizToast != null && quizToast.id != _lastQuizToastId) {
      _lastQuizToastId = quizToast.id;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showQuizToast(quizToast),
      );
    }
    if (widget.controller.messages.length != _lastMessageCount) {
      _lastMessageCount = widget.controller.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _showQuizToast(ClassQuizToast toast) {
    if (!mounted) return;
    _removeQuizToast();

    final media = MediaQuery.of(context);
    final scale = AppSpacing.of(context);
    final isWide = scale.showsSideRail;

    _quizToastOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
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
                color: toast.isCorrect
                    ? AppTheme.successToast
                    : AppTheme.errorToast,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.floatingShadow,
              ),
              child: Row(
                children: [
                  Text(
                    toast.isCorrect ? '🎉' : '💡',
                    style: const TextStyle(fontSize: 20),
                  ),
                  SizedBox(width: scale.sm),
                  Expanded(
                    child: Text(
                      toast.isCorrect
                          ? 'Correct Answer!  +${toast.points} points'
                          : 'Not quite. Correct answer: ${toast.correctAnswer ?? ''}',
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
    Overlay.of(context).insert(_quizToastOverlay!);
    _quizToastTimer = Timer(
      Duration(milliseconds: toast.isCorrect ? 1400 : 2300),
      _removeQuizToast,
    );
  }

  void _removeQuizToast() {
    _quizToastTimer?.cancel();
    _quizToastTimer = null;
    _quizToastOverlay?.remove();
    _quizToastOverlay = null;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;

        if (controller.outcome == ClassSessionOutcome.weeklyCapReached) {
          return ClassWeeklyCapRevealBody(
            unitIndex: controller.unitIndex,
            onHome: () => context.go(AppRoutes.home),
          );
        }

        final showChoiceReveal =
            controller.outcome == ClassSessionOutcome.choice;
        final isVideoStartCheckpoint =
            controller.messages.length == 1 &&
            controller.messages.first.contentType ==
                ClassChatContentType.checkpoint &&
            controller.messages.first.data['action'] == 'video';

        return Column(
          children: [
            AppHeader(
              title: controller.unitName,
              points: controller.displayedTotalPoints,
              showBack: true,
              showPoints: true,
              showAskBuddy: true,
              onBack: () => context.go(AppRoutes.home),
            ),
            Expanded(
              child: Container(
                color: AppTheme.appBackground,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = AppSpacingScale.fromWidth(
                      constraints.maxWidth,
                    );

                    if (isVideoStartCheckpoint) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: scale.contentMaxWidth,
                          ),
                          child: ClassCheckpointCard(
                            message: controller.messages.first,
                            controller: controller,
                            fillAvailableHeight: true,
                          ),
                        ),
                      );
                    }

                    final chatList = ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        scale.md,
                        scale.lg,
                        scale.md,
                        scale.xxl,
                      ),
                      itemCount:
                          controller.messages.length +
                          (showChoiceReveal ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < controller.messages.length) {
                          final message = controller.messages[index];
                          return ClassChatBubbleRow(
                            key: ValueKey(message.id),
                            message: message,
                            controller: controller,
                          );
                        }
                        return ClassNextActivityInlineCard(
                          controller: controller,
                          onStartNextActivity: widget.onStartNextActivity,
                        );
                      },
                    );

                    if (!scale.showsSideRail) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: scale.chatMaxWidth,
                          ),
                          child: Container(
                            color: AppTheme.classroomBackground,
                            child: chatList,
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: scale.contentMaxWidth,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: scale.pageGutter,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: scale.sm,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: scale.chatMaxWidth,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.classroomBackground,
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusXl,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: chatList,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: scale.railWidth + scale.xl,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: scale.xl,
                                    top: scale.lg,
                                    bottom: scale.lg,
                                  ),
                                  child: ClassRevealRail(
                                    unitIndex: controller.unitIndex,
                                    revealProgress: showChoiceReveal
                                        ? 1
                                        : controller.revealProgress,
                                    studentName: controller.studentName,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
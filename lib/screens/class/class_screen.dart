import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/class_chat_message_model.dart';
import '../../providers/class_chat_controller.dart';
import '../../providers/class_chat_provider.dart';
import '../../providers/class_session_bootstrap_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_nav.dart';
import 'widgets/class_chat_row.dart';
import 'widgets/class_loading_skeleton.dart';
import 'widgets/class_message_content.dart';
import 'widgets/class_reveal_widgets.dart';

class ClassScreen extends ConsumerStatefulWidget {
  const ClassScreen({super.key});

  @override
  ConsumerState<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends ConsumerState<ClassScreen> {
  int _attempt = 0;

  void _startNextActivity() {
    setState(() => _attempt++);
    ref.invalidate(classSessionBootstrapProvider);
  }

  @override
  Widget build(BuildContext context) {
    final controllerAsync = ref.watch(classChatControllerProvider(_attempt));

    return AppNav(
      child: Scaffold(
        backgroundColor: AppTheme.appBackground,
        body: controllerAsync.when(
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
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onBack});

  final Object error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isNoEnrollment = error is NoActiveEnrollmentException;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isNoEnrollment
                  ? "You're not enrolled in a course yet."
                  : 'Something went wrong loading your class.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go home'),
            ),
          ],
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
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.messages.length != _lastMessageCount) {
      _lastMessageCount = widget.controller.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
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
        if (widget.controller.outcome == ClassSessionOutcome.weeklyCapReached) {
          return ClassWeeklyCapRevealBody(
            unitIndex: widget.controller.unitIndex,
            onHome: () => context.go(AppRoutes.home),
          );
        }

        final showChoiceReveal =
            widget.controller.outcome == ClassSessionOutcome.choice;
        final isVideoStartCheckpoint =
            widget.controller.messages.length == 1 &&
            widget.controller.messages.first.contentType ==
                ClassChatContentType.checkpoint &&
            widget.controller.messages.first.data['action'] == 'video';

        return Column(
          children: [
            AppHeader(
              title: widget.controller.unitName,
              points: widget.controller.displayedTotalPoints,
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
                    final showRail = constraints.maxWidth >= 640;

                    if (isVideoStartCheckpoint) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1060),
                          child: ClassCheckpointCard(
                            message: widget.controller.messages.first,
                            controller: widget.controller,
                            fillAvailableHeight: true,
                          ),
                        ),
                      );
                    }

                    final chatColumn = ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
                      itemCount:
                          widget.controller.messages.length +
                          (showChoiceReveal ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < widget.controller.messages.length) {
                          final message = widget.controller.messages[index];
                          return ClassChatBubbleRow(
                            key: ValueKey(message.id),
                            message: message,
                            controller: widget.controller,
                          );
                        }
                        return ClassNextActivityInlineCard(
                          controller: widget.controller,
                          onStartNextActivity: widget.onStartNextActivity,
                        );
                      },
                    );

                    if (!showRail) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Container(
                            color: AppTheme.classroomBackground,
                            child: chatColumn,
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1060),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  60,
                                  14,
                                  0,
                                  14,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 700,
                                  ),
                                  child: Container(
                                    color: AppTheme.classroomBackground,
                                    child: chatColumn,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  34,
                                  20,
                                  16,
                                  20,
                                ),
                                child: ClassRevealRail(
                                  unitIndex: widget.controller.unitIndex,
                                  revealProgress: showChoiceReveal
                                      ? 1
                                      : widget.controller.revealProgress,
                                  studentName: widget.controller.studentName,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (widget.controller.isAwaitingContinue && !showChoiceReveal)
              ClassContinueBar(
                onContinue: widget.controller.continueAfterReview,
              ),
          ],
        );
      },
    );
  }
}

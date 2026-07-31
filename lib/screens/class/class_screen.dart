import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/class_chat_message_model.dart';
import '../../models/submission_answer_model.dart';
import '../../providers/class_chat_controller.dart';
import '../../providers/class_chat_provider.dart';
import '../../providers/class_session_bootstrap_provider.dart';
import '../../providers/learner_state_provider.dart';
import '../../providers/reveal_asset_resolver.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_nav.dart';
import 'widgets/class_loading_skeleton.dart';

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
        backgroundColor: const Color(0xFFF6F6F9),
        body: controllerAsync.when(
          loading: () => const ClassLoadingSkeleton(),
          error: (error, _) {
            if (error is NoUnitAvailableException) {
              return _WeeklyCapRevealBody(
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
          return _WeeklyCapRevealBody(
            unitIndex: widget.controller.unitIndex,
            onHome: () => context.go(AppRoutes.home),
          );
        }

        final showChoiceReveal =
            widget.controller.outcome == ClassSessionOutcome.choice;

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
                color: const Color(0xFFF6F6F9),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showRail = constraints.maxWidth >= 640;

                    final chatColumn = ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
                      itemCount:
                          widget.controller.messages.length +
                          (showChoiceReveal ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < widget.controller.messages.length) {
                          final message = widget.controller.messages[index];
                          return _ChatBubbleRow(
                            key: ValueKey(message.id),
                            message: message,
                            controller: widget.controller,
                          );
                        }
                        return _NextActivityInlineCard(
                          controller: widget.controller,
                          onStartNextActivity: widget.onStartNextActivity,
                        );
                      },
                    );

                    if (!showRail) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: chatColumn,
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: chatColumn,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 16, 20),
                            child: _RevealRail(
                              unitIndex: widget.controller.unitIndex,
                              revealed: showChoiceReveal,
                              studentName: widget.controller.studentName,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (widget.controller.isAwaitingContinue && !showChoiceReveal)
              _ContinueBar(onContinue: widget.controller.continueAfterReview),
          ],
        );
      },
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E2EA))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealImage extends StatelessWidget {
  const _RevealImage({
    required this.unitIndex,
    required this.revealed,
    this.height = 150,
  });

  final int unitIndex;
  final bool revealed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: RevealAssetResolver.resolve(unitIndex),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: height,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.buttonColor),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                snapshot.data!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: height,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: height,
                  color: const Color(0xFFEFEFF4),
                  child: const Icon(
                    Icons.image_rounded,
                    size: 40,
                    color: Color(0xFF9C9DAB),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: revealed ? 0 : 1,
                duration: const Duration(milliseconds: 500),
                child: Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              if (!revealed)
                Positioned(
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Finish today to reveal',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.buttonColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NextActivityInlineCard extends ConsumerWidget {
  const _NextActivityInlineCard({
    required this.controller,
    required this.onStartNextActivity,
  });

  final ClassChatController controller;
  final VoidCallback onStartNextActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Watch another video?',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6E6E7A),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.volume_up_rounded,
                size: 16,
                color: Color(0xFF9C9DAB),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E2EA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 96,
                    height: 96,
                    color: const Color(0xFFF4F4F6),
                    child: const Icon(
                      Icons.image_rounded,
                      size: 30,
                      color: Color(0xFF9C9DAB),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.courseDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF9C9DAB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.unitName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "YOU'LL EARN",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: const Color(0xFF9C9DAB),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _EarnRow(
                        icon: Icons.stars_rounded,
                        iconColor: const Color(0xFFE29A22),
                        label: '${controller.sessionTotalPoints} Points',
                      ),
                      const SizedBox(height: 4),
                      const _EarnRow(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: Color(0xFF24A866),
                        label: '1 streak',
                      ),
                      const SizedBox(height: 4),
                      const _EarnRow(
                        icon: Icons.diamond_rounded,
                        iconColor: AppTheme.buttonColor,
                        label: '1 skill gem',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onStartNextActivity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Let's go 🎉"),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.invalidate(
                        learnerStateDataProvider(controller.learnerId),
                      );
                      context.go(AppRoutes.home);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mutedLavender,
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
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _WeeklyCapRevealBody extends StatelessWidget {
  const _WeeklyCapRevealBody({required this.unitIndex, required this.onHome});

  final int unitIndex;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F6F9),
      width: double.infinity,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showRail = constraints.maxWidth >= 640;
          final message = Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You did really well this week! 🎉',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You've completed your activities for this week. See you next week!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF6E6E7A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 220,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.buttonColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Back to home'),
                    ),
                  ),
                ],
              ),
            ),
          );

          if (!showRail) return message;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: message),
              SizedBox(
                width: 220,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 16, 20),
                  child: _RevealRail(
                    unitIndex: unitIndex,
                    revealed: true,
                    studentName: null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RevealRail extends StatelessWidget {
  const _RevealRail({
    required this.unitIndex,
    required this.revealed,
    required this.studentName,
  });

  final int unitIndex;
  final bool revealed;
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E2EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.mutedLavender,
                child: ClipOval(
                  child: Image.asset(
                    'assets/onboarding/TAP-bot.png',
                    fit: BoxFit.cover,
                    width: 28,
                    height: 28,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.emoji_events_rounded,
                      size: 15,
                      color: Color(0xFFE29A22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Today's picture",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C21),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            revealed
                ? 'Congratulations !!🎉 You have unlocked today\'s picture'
                : 'Keep going${studentName != null ? ', $studentName' : ''} — finish today\'s activity to unlock this picture',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: const Color(0xFF4A4A55),
            ),
          ),
          const SizedBox(height: 12),
          _RevealImage(unitIndex: unitIndex, revealed: revealed, height: 160),
        ],
      ),
    );
  }
}

class _ChatBubbleRow extends StatelessWidget {
  const _ChatBubbleRow({
    super.key,
    required this.message,
    required this.controller,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ClassChatSender.user;

    if (message.contentType == ClassChatContentType.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(child: _TypingIndicator()),
      );
    }

    if (message.contentType == ClassChatContentType.checkpoint) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _CheckpointCard(message: message, controller: controller),
      );
    }

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: _BubbleContent(
                  message: message,
                  controller: controller,
                  isUser: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const _Avatar(isUser: true),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _Avatar(isUser: false),
          const SizedBox(width: 8),
          Expanded(
            child: _BubbleContent(
              message: message,
              controller: controller,
              isUser: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isUser});

  final bool isUser;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE1E2EA)),
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 16,
          color: AppTheme.buttonColor,
        ),
      );
    }

    return CircleAvatar(
      radius: 15,
      backgroundColor: AppTheme.buttonColor,
      child: ClipOval(
        child: Image.asset(
          'assets/onboarding/TAP-bot.png',
          fit: BoxFit.cover,
          width: 30,
          height: 30,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.smart_toy_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: 40,
        height: 16,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(3, (i) {
                final t = (_controller.value + (i * 0.2)) % 1.0;
                final scale =
                    0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scale,
                  child: const CircleAvatar(
                    radius: 3,
                    backgroundColor: Color(0xFF9C9DAB),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({
    required this.message,
    required this.controller,
    required this.isUser,
  });

  final ClassChatMessage message;
  final ClassChatController controller;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    switch (message.contentType) {
      case ClassChatContentType.text:
      case ClassChatContentType.unitTransition:
        return _TextBubble(text: message.text ?? '', isUser: isUser);
      case ClassChatContentType.checkpoint:
        return _CheckpointCard(message: message, controller: controller);
      case ClassChatContentType.video:
        return _VideoCard(
          key: ValueKey('video_${message.id}'),
          message: message,
          controller: controller,
        );
      case ClassChatContentType.submission:
        return _SubmissionCard(
          key: ValueKey('submission_${message.id}'),
          message: message,
          controller: controller,
        );
      case ClassChatContentType.submissionAnswerEcho:
        return _TextBubble(text: message.text ?? '', isUser: true);
      case ClassChatContentType.submissionReviewing:
        return const _TextBubble(
          text: 'Reviewing your submission...',
          isUser: false,
          isMuted: true,
        );
      case ClassChatContentType.submissionReview:
        return _SubmissionReviewCard(message: message);
      case ClassChatContentType.quizQuestion:
        return isUser
            ? _TextBubble(text: message.text ?? '', isUser: true)
            : _QuizQuestionCard(
                key: ValueKey('quiz_${message.id}'),
                message: message,
                controller: controller,
              );
      case ClassChatContentType.quizAnswerEcho:
        return _TextBubble(text: message.text ?? '', isUser: true);
      case ClassChatContentType.quizFeedback:
        return _QuizFeedbackCard(message: message);
      case ClassChatContentType.quizSummary:
        return _QuizSummaryCard(message: message);
      case ClassChatContentType.sessionEnd:
      case ClassChatContentType.weeklyCapReached:
        return const SizedBox.shrink();
      case ClassChatContentType.errorRetry:
        return _ErrorRetryCard(message: message, controller: controller);
      case ClassChatContentType.loading:
        return const SizedBox.shrink();
    }
  }
}

class _CheckpointCard extends StatelessWidget {
  const _CheckpointCard({required this.message, required this.controller});

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  Widget build(BuildContext context) {
    final image = message.data['image'] as String?;
    final buttonLabel = message.data['buttonLabel'] as String? ?? 'Continue';
    final action = message.data['action'] as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E7EF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TapBuddySpeakingOrb(),
          const SizedBox(height: 12),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.volume_up_rounded,
                  size: 15,
                  color: AppTheme.buttonColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Hear again',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.buttonColor,
                  ),
                ),
              ],
            ),
          ),
          if (image != null) ...[
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230, maxWidth: 360),
              child: Image.asset(
                image,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              message.text ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2C2C34),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 280,
            height: 48,
            child: ElevatedButton(
              onPressed: action.isEmpty
                  ? null
                  : () => controller.continueCheckpoint(action),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                buttonLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapBuddySpeakingOrb extends StatelessWidget {
  const _TapBuddySpeakingOrb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      height: 136,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: const Color(0xFFB9AAFF).withValues(alpha: 0.52),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: const Color(0xFF8F80FF).withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 94,
            height: 94,
            decoration: const BoxDecoration(
              color: Color(0xFF292930),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/onboarding/TAP-bot.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.smart_toy_rounded, size: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'TAP Buddy',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Speaking',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.text,
    required this.isUser,
    this.isMuted = false,
  });

  final String text;
  final bool isUser;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.buttonColor, Color(0xFF6E6EE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.4,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: const Color(0xFFE1E2EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                fontStyle: isMuted ? FontStyle.italic : FontStyle.normal,
                color: const Color(0xFF1C1C21),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.volume_up_rounded,
            size: 18,
            color: Color(0xFF9C9DAB),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E2EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({
    super.key,
    required this.message,
    required this.controller,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  YoutubePlayerController? _ytController;
  String? _initializedForYoutubeId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    final youtubeId = widget.message.data['youtubeId'] as String? ?? '';
    if (youtubeId.isNotEmpty) {
      _ensureController(youtubeId);
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  void _ensureController(String youtubeId) {
    if (_initializedForYoutubeId == youtubeId && _ytController != null) return;
    _ytController?.dispose();
    _ytController = YoutubePlayerController(
      initialVideoId: youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        forceHD: false,
      ),
    )..cue(youtubeId);
    _initializedForYoutubeId = youtubeId;
  }

  Future<void> _openOnWeb(String youtubeId) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$youtubeId');
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final watched = widget.message.data['watched'] == true;
    final title = widget.message.data['title'] as String? ?? '';
    final description = widget.message.data['description'] as String? ?? '';
    final points = widget.message.data['points'] as int? ?? 0;
    final youtubeId = widget.message.data['youtubeId'] as String? ?? '';

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: youtubeId.isEmpty
                ? AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.videocam_off_rounded,
                          size: 40,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  )
                : kIsWeb
                ? _WebVideoThumb(
                    youtubeId: youtubeId,
                    onTap: () => _openOnWeb(youtubeId),
                  )
                : AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _ytController == null
                        ? Container(color: Colors.black)
                        : YoutubePlayer(
                            key: ValueKey('yt_$youtubeId'),
                            controller: _ytController!,
                            showVideoProgressIndicator: true,
                            progressIndicatorColor: AppTheme.buttonColor,
                          ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF6E6E7A),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: watched
                  ? null
                  : () {
                      widget.controller.markVideoWatched();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD9DAE4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                watched ? 'Watched' : 'I watched it • +$points points',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebVideoThumb extends StatelessWidget {
  const _WebVideoThumb({required this.youtubeId, required this.onTap});

  final String youtubeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.videocam_off_rounded,
                      size: 40,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
              Container(color: Colors.black.withValues(alpha: 0.18)),
              Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 34,
                    color: Color(0xFF1C1C21),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Watch on YouTube',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  const _SubmissionCard({
    super.key,
    required this.message,
    required this.controller,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedEmoji;
  XFile? _pickedMedia;
  Uint8List? _pickedMediaBytes;
  bool _isVideoPick = false;
  bool _isPicking = false;
  bool _submitted = false;
  bool _pickError = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _markSubmitted() {
    setState(() => _submitted = true);
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isPicking = true;
      _pickError = false;
    });
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _pickedMedia = file;
          _pickedMediaBytes = bytes;
          _isVideoPick = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pickError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't access that. Please try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    setState(() {
      _isPicking = true;
      _pickError = false;
    });
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (file != null) {
        if (!mounted) return;
        setState(() {
          _pickedMedia = file;
          _pickedMediaBytes = null;
          _isVideoPick = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pickError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't access that. Please try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _showMediaSourceSheet({required bool allowVideo}) async {
    final choice = await showModalBottomSheet<_MediaPickChoice>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, _MediaPickChoice.cameraImage),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo from gallery'),
              onTap: () =>
                  Navigator.pop(context, _MediaPickChoice.galleryImage),
            ),
            if (allowVideo) ...[
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record a video'),
                onTap: () =>
                    Navigator.pop(context, _MediaPickChoice.cameraVideo),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Choose video from gallery'),
                onTap: () =>
                    Navigator.pop(context, _MediaPickChoice.galleryVideo),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    switch (choice) {
      case _MediaPickChoice.cameraImage:
        await _pickImage(ImageSource.camera);
        break;
      case _MediaPickChoice.galleryImage:
        await _pickImage(ImageSource.gallery);
        break;
      case _MediaPickChoice.cameraVideo:
        await _pickVideo(ImageSource.camera);
        break;
      case _MediaPickChoice.galleryVideo:
        await _pickVideo(ImageSource.gallery);
        break;
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignmentName =
        widget.message.data['assignmentName'] as String? ?? '';
    final unguidedText = widget.message.data['unguidedText'] as String? ?? '';
    final subTypes = widget.message.data['subTypes'] as String? ?? '';
    final kind = SubmissionKindResolver.fromSubTypes(subTypes);
    final stepNumber = widget.message.data['stepNumber'] as int?;
    final stepTotal = widget.message.data['stepTotal'] as int?;
    final isAwaiting = widget.controller.isAwaitingInput;
    final canInteract = isAwaiting && !_submitted;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignmentName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stepNumber != null && stepTotal != null
                      ? 'Step $stepNumber/$stepTotal'
                      : "Today's activity",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6E6E7A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            unguidedText,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: const Color(0xFF6E6E7A),
            ),
          ),
          const SizedBox(height: 16),
          if (_pickError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3C4BE)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppTheme.dangerText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "We couldn't load that photo. Please try picking it again.",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.dangerText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _buildInputForKind(kind, canInteract),
        ],
      ),
    );
  }

  Widget _buildInputForKind(SubmissionKind kind, bool canInteract) {
    switch (kind) {
      case SubmissionKind.emoji:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['👍', '👎', '😊', '😕', '💪', '🤔'].map((emoji) {
                final selected = _selectedEmoji == emoji;
                return InkWell(
                  onTap: canInteract
                      ? () => setState(() => _selectedEmoji = emoji)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE5E4FA)
                          : const Color(0xFFF4F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _submitRow(
              onPressed: (canInteract && _selectedEmoji != null)
                  ? () {
                      widget.controller.submitAssignmentAnswer(
                        SubmissionAnswer.emoji(_selectedEmoji!),
                      );
                      _markSubmitted();
                    }
                  : null,
            ),
          ],
        );

      case SubmissionKind.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              enabled: canInteract,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your answer here...',
                filled: true,
                fillColor: const Color(0xFFF4F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _submitRow(
              onPressed: canInteract
                  ? () {
                      if (_textController.text.trim().isEmpty) return;
                      widget.controller.submitAssignmentAnswer(
                        SubmissionAnswer.text(_textController.text.trim()),
                      );
                      _markSubmitted();
                    }
                  : null,
            ),
          ],
        );

      case SubmissionKind.textAudio:
      case SubmissionKind.audio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              enabled: canInteract,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type or transcribe your answer here...',
                filled: true,
                fillColor: const Color(0xFFF4F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _submitRow(
              onPressed: canInteract
                  ? () {
                      if (_textController.text.trim().isEmpty) return;
                      widget.controller.submitAssignmentAnswer(
                        SubmissionAnswer.audioTranscript(
                          _textController.text.trim(),
                        ),
                      );
                      _markSubmitted();
                    }
                  : null,
            ),
          ],
        );

      case SubmissionKind.image:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: false,
          onSubmit: () {
            if (_pickedMedia == null) return;
            widget.controller.submitAssignmentAnswer(
              SubmissionAnswer.image(_pickedMedia!.path),
            );
            _markSubmitted();
          },
        );

      case SubmissionKind.video:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: true,
          forceVideo: true,
          onSubmit: () {
            if (_pickedMedia == null) return;
            widget.controller.submitAssignmentAnswer(
              SubmissionAnswer.video(_pickedMedia!.path),
            );
            _markSubmitted();
          },
        );

      case SubmissionKind.imageVideo:
        return _buildMediaPicker(
          canInteract: canInteract,
          allowVideo: true,
          onSubmit: () {
            if (_pickedMedia == null) return;
            widget.controller.submitAssignmentAnswer(
              SubmissionAnswer.imageOrVideo(
                _pickedMedia!.path,
                isVideo: _isVideoPick,
              ),
            );
            _markSubmitted();
          },
        );
    }
  }

  Widget _buildMediaPicker({
    required bool canInteract,
    required bool allowVideo,
    required VoidCallback onSubmit,
    bool forceVideo = false,
  }) {
    final hasMedia = _pickedMedia != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMedia)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _isVideoPick
                ? Container(
                    width: double.infinity,
                    height: 160,
                    color: const Color(0xFF1C1C21),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  )
                : (_pickedMediaBytes != null
                      ? Image.memory(
                          _pickedMediaBytes!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: double.infinity,
                                height: 160,
                                color: const Color(0xFFEFEFF4),
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  size: 32,
                                  color: Color(0xFF9C9DAB),
                                ),
                              ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 160,
                          color: const Color(0xFFEFEFF4),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )),
          )
        else
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E2EA)),
            ),
            child: Icon(
              forceVideo ? Icons.videocam_outlined : Icons.image_outlined,
              size: 32,
              color: const Color(0xFF9C9DAB),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: (canInteract && !_isPicking)
              ? () => _showMediaSourceSheet(allowVideo: allowVideo)
              : null,
          icon: _isPicking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  hasMedia
                      ? Icons.refresh_rounded
                      : (forceVideo
                            ? Icons.videocam_outlined
                            : Icons.photo_camera_outlined),
                ),
          label: Text(
            hasMedia
                ? 'Choose different file'
                : (forceVideo
                      ? 'Record or upload a video'
                      : 'Take or upload a photo'),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.buttonColor,
            side: const BorderSide(color: AppTheme.buttonColor),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
        const SizedBox(height: 12),
        _submitRow(onPressed: (canInteract && hasMedia) ? onSubmit : null),
      ],
    );
  }

  Widget _submitRow({required VoidCallback? onPressed}) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD9DAE4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_submitted ? 'Sent' : 'Submit'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6E6E7A),
              side: const BorderSide(color: Color(0xFFDCDDE7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Submission Help'),
          ),
        ),
      ],
    );
  }
}

enum _MediaPickChoice { cameraImage, galleryImage, cameraVideo, galleryVideo }

class _SubmissionReviewCard extends StatelessWidget {
  const _SubmissionReviewCard({required this.message});

  final ClassChatMessage message;

  @override
  Widget build(BuildContext context) {
    final feedback = message.data['feedback'] as String?;
    final score = message.data['score'] as int?;
    final passed = message.data['passed'] as bool?;
    final text = message.text ?? '';
    final failed = passed == false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: failed ? const Color(0xFFFDEDEB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: failed ? const Color(0xFFEBAFA6) : const Color(0xFFE1E2EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (failed) ...[
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: AppTheme.dangerText,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: failed
                        ? AppTheme.dangerText
                        : const Color(0xFF1C1C21),
                  ),
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: failed
                        ? const Color(0xFFF9D9D3)
                        : const Color(0xFFE7F7EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Score: $score',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: failed
                          ? AppTheme.dangerText
                          : const Color(0xFF24A866),
                    ),
                  ),
                ),
            ],
          ),
          if (feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              feedback,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: failed ? AppTheme.dangerText : const Color(0xFF6E6E7A),
              ),
            ),
          ],
          if (failed) ...[
            const SizedBox(height: 8),
            Text(
              'No submission points were added for this attempt.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.dangerText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizQuestionCard extends StatefulWidget {
  const _QuizQuestionCard({
    super.key,
    required this.message,
    required this.controller,
  });

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  State<_QuizQuestionCard> createState() => _QuizQuestionCardState();
}

class _QuizQuestionCardState extends State<_QuizQuestionCard> {
  String? _selectedKey;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final questionIndex = widget.message.data['questionIndex'] as int? ?? 0;
    final totalQuestions = widget.message.data['totalQuestions'] as int? ?? 0;
    final question = widget.message.data['question'] as String? ?? '';
    final options =
        (widget.message.data['options'] as Map?)?.cast<String, String>() ??
        const {};
    final answerKey = widget.message.data['answerKey'] as String?;
    final optionEntries = options.entries.toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E2EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${questionIndex + 1}. $question',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Question ${questionIndex + 1} of $totalQuestions',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9C9DAB),
            ),
          ),
          const SizedBox(height: 14),
          ...optionEntries.map((option) {
            final selected = _selectedKey == option.key;
            final isCorrectOption =
                answerKey != null && option.key == answerKey;

            Color fillColor = Colors.white;
            Color borderColor = const Color(0xFFE1E2EA);
            Color textColor = const Color(0xFF1C1C21);

            if (_confirmed) {
              if (isCorrectOption) {
                fillColor = AppTheme.buttonColor;
                borderColor = AppTheme.buttonColor;
                textColor = Colors.white;
              } else if (selected) {
                fillColor = const Color(0xFFFBECEA);
                borderColor = const Color(0xFFD98F86);
                textColor = AppTheme.dangerText;
              }
            } else if (selected) {
              borderColor = AppTheme.buttonColor;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: (widget.controller.isAwaitingInput && !_confirmed)
                    ? () => setState(() => _selectedKey = option.key)
                    : null,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: borderColor,
                      width: selected || (_confirmed && isCorrectOption)
                          ? 1.8
                          : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.value,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (_confirmed && isCorrectOption)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      if (_confirmed && selected && !isCorrectOption)
                        Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: AppTheme.dangerText,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed:
                  (widget.controller.isAwaitingInput &&
                      _selectedKey != null &&
                      !_confirmed)
                  ? () {
                      setState(() => _confirmed = true);
                      widget.controller.submitQuizAnswer(_selectedKey!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E4FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizFeedbackCard extends StatelessWidget {
  const _QuizFeedbackCard({required this.message});

  final ClassChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isCorrect = message.data['isCorrect'] as bool? ?? false;
    final explanation = message.data['explanation'] as String?;
    final correctOptionText = message.data['correctOptionText'] as String?;
    final earnedPoints = message.data['earnedPoints'] as int?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFE7F7EE) : const Color(0xFFFFF1E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
                size: 18,
                color: isCorrect
                    ? const Color(0xFF24A866)
                    : const Color(0xFFE29A22),
              ),
              const SizedBox(width: 6),
              Text(
                isCorrect
                    ? (earnedPoints != null
                          ? 'Correct! +$earnedPoints points'
                          : 'Correct!')
                    : 'Not quite',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (!isCorrect && correctOptionText != null) ...[
            const SizedBox(height: 8),
            Text(
              'Correct answer: $correctOptionText',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A4A55),
              ),
            ),
          ],
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: const Color(0xFF4A4A55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizSummaryCard extends StatelessWidget {
  const _QuizSummaryCard({required this.message});

  final ClassChatMessage message;

  @override
  Widget build(BuildContext context) {
    final correct = message.data['correct'] as int? ?? 0;
    final total = message.data['total'] as int? ?? 0;

    return _CardShell(
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFF4AC38),
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${message.text ?? 'Quiz done!'}\nYou got $correct out of $total correct.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetryCard extends StatelessWidget {
  const _ErrorRetryCard({required this.message, required this.controller});

  final ClassChatMessage message;
  final ClassChatController controller;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text ?? 'Something went wrong.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: controller.retryAfterError,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

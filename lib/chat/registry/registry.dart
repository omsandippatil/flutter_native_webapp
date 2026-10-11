import 'package:flutter/widgets.dart';

import 'package:tapapp/chat/action/action.dart';
import 'package:tapapp/chat/audio/audio.dart';
import 'package:tapapp/chat/blocks/checkpoint_block.dart';
import 'package:tapapp/chat/blocks/choice_block.dart';
import 'package:tapapp/chat/blocks/divider_block.dart';
import 'package:tapapp/chat/blocks/error_block.dart';
import 'package:tapapp/chat/blocks/form_block.dart';
import 'package:tapapp/chat/blocks/image_block.dart';
import 'package:tapapp/chat/blocks/next_activity_block.dart';
import 'package:tapapp/chat/blocks/profile_verify_block.dart';
import 'package:tapapp/chat/blocks/quiz_block.dart';
import 'package:tapapp/chat/blocks/quiz_summary_block.dart';
import 'package:tapapp/chat/blocks/scorecard_block.dart';
import 'package:tapapp/chat/blocks/submission_block.dart';
import 'package:tapapp/chat/blocks/submission_review_block.dart';
import 'package:tapapp/chat/blocks/submission_reward_block.dart';
import 'package:tapapp/chat/blocks/text_block.dart';
import 'package:tapapp/chat/blocks/typing_indicator_block.dart';
import 'package:tapapp/chat/blocks/video_block.dart';
import 'package:tapapp/chat/model/model.dart';
import 'package:tapapp/chat/submission/submission.dart';

typedef ChatActionCallback =
    void Function(ChatAction action, {Map<String, Object?>? data});
typedef ChatCheckpointCallback = void Function(CheckpointItem item);
typedef ChatOptionCallback = void Function(String stepId, String optionKey);
typedef ChatSubmissionCallback = void Function(String stepId, Object answer);
typedef ChatRetryCallback = void Function(String? retryAction);

class ChatRenderContext {
  const ChatRenderContext({
    required this.onAction,
    required this.onOptionSelected,
    required this.onSubmissionAnswer,
    required this.onRetry,
    required this.audioController,
    this.onCheckpoint,
    this.submissionContentFetcher,
    this.studentName = 'Champ',
    this.courseDisplay = '',
    this.isAwaitingInput = true,
  });

  final ChatActionCallback onAction;
  final ChatOptionCallback onOptionSelected;
  final ChatSubmissionCallback onSubmissionAnswer;
  final ChatRetryCallback onRetry;
  final ChatCheckpointCallback? onCheckpoint;
  final ChatAudioPlaybackController audioController;
  final SubmissionContentFetcher? submissionContentFetcher;
  final String studentName;
  final String courseDisplay;
  final bool isAwaitingInput;

  void checkpoint(CheckpointItem item) {
    final handler = onCheckpoint;
    if (handler != null) {
      handler(item);
      return;
    }
    onAction(
      ChatAction.continueFlow,
      data: {'stepId': item.stepId, 'checkpointAction': item.action},
    );
  }

  ChatRenderContext copyWith({
    ChatActionCallback? onAction,
    ChatOptionCallback? onOptionSelected,
    ChatSubmissionCallback? onSubmissionAnswer,
    ChatRetryCallback? onRetry,
    ChatCheckpointCallback? onCheckpoint,
    ChatAudioPlaybackController? audioController,
    SubmissionContentFetcher? submissionContentFetcher,
    String? studentName,
    String? courseDisplay,
    bool? isAwaitingInput,
  }) => ChatRenderContext(
    onAction: onAction ?? this.onAction,
    onOptionSelected: onOptionSelected ?? this.onOptionSelected,
    onSubmissionAnswer: onSubmissionAnswer ?? this.onSubmissionAnswer,
    onRetry: onRetry ?? this.onRetry,
    onCheckpoint: onCheckpoint ?? this.onCheckpoint,
    audioController: audioController ?? this.audioController,
    submissionContentFetcher:
        submissionContentFetcher ?? this.submissionContentFetcher,
    studentName: studentName ?? this.studentName,
    courseDisplay: courseDisplay ?? this.courseDisplay,
    isAwaitingInput: isAwaitingInput ?? this.isAwaitingInput,
  );
}

typedef ChatCardBuilder = Widget Function(ChatItem item, ChatRenderContext ctx);

Widget _unsupported(ChatItem item, ChatRenderContext ctx) => ErrorBlock(
  item: ErrorItem(id: item.id, stepId: item.stepId, message: 'Something went wrong.'),
  ctx: ctx,
);

final Map<ChatItemKind, ChatCardBuilder> chatBlockRegistry = {
  ChatItemKind.text: (item, ctx) => TextBlock(
    text: item.text ?? '',
    isUser: item.sender == ChatSender.user,
    isMuted: item.isMuted,
    showSpeakerIcon: item.audio == null,
  ),
  ChatItemKind.image: (item, ctx) => item is ImageItem
      ? ImageBlock(src: item.src, caption: item.caption, alt: item.alt)
      : _unsupported(item, ctx),
  ChatItemKind.divider: (item, ctx) =>
      DividerBlock(label: item is DividerItem ? item.label : (item.text ?? '')),
  ChatItemKind.quiz: (item, ctx) => item is QuizItem
      ? QuizBlock(key: ValueKey('quiz_${item.id}'), item: item, ctx: ctx)
      : _unsupported(item, ctx),
  ChatItemKind.quizSummary: (item, ctx) =>
      item is QuizSummaryItem ? QuizSummaryBlock(item: item) : _unsupported(item, ctx),
  ChatItemKind.submission: (item, ctx) => item is SubmissionItem
      ? SubmissionBlock(key: ValueKey('submission_${item.id}'), item: item, ctx: ctx)
      : _unsupported(item, ctx),
  ChatItemKind.submissionReview: (item, ctx) => item is SubmissionReviewItem
      ? SubmissionReviewBlock(item: item)
      : _unsupported(item, ctx),
  ChatItemKind.submissionReward: (item, ctx) => item is SubmissionRewardItem
      ? SubmissionRewardBlock(item: item, ctx: ctx)
      : _unsupported(item, ctx),
  ChatItemKind.video: (item, ctx) => item is VideoItem
      ? VideoBlock(key: ValueKey('video_${item.id}'), item: item, ctx: ctx)
      : _unsupported(item, ctx),
  ChatItemKind.choice: (item, ctx) => item is ChoiceItem
      ? ChoiceBlock(key: ValueKey('choice_${item.id}'), item: item, ctx: ctx)
      : _unsupported(item, ctx),
  ChatItemKind.form: (item, ctx) => item is FormItem
      ? FormBlock(key: ValueKey('form_${item.id}'), item: item, ctx: ctx)
      : _unsupported(item, ctx),
  ChatItemKind.profileVerify: (item, ctx) => item is ProfileVerifyItem
      ? ProfileVerifyBlock(item: item, ctx: ctx)
      : _unsupported(item, ctx),
  ChatItemKind.checkpoint: (item, ctx) =>
      item is CheckpointItem ? checkpointBlockFor(item, ctx) : _unsupported(item, ctx),
  ChatItemKind.scorecard: (item, ctx) =>
      item is ScorecardItem ? ScorecardBlock(item: item) : _unsupported(item, ctx),
  ChatItemKind.nextActivity: (item, ctx) => item is NextActivityItem
      ? NextActivityBlock(item: item, ctx: ctx)
      : _unsupported(item, ctx),
  ChatItemKind.loading: (item, ctx) => const Center(child: TypingIndicatorBlock()),
  ChatItemKind.error: (item, ctx) =>
      item is ErrorItem ? ErrorBlock(item: item, ctx: ctx) : _unsupported(item, ctx),
};

void registerChatBuilder(ChatItemKind kind, ChatCardBuilder builder) {
  chatBlockRegistry[kind] = builder;
}

Widget buildChatItem(ChatItem item, ChatRenderContext ctx) {
  final builder = chatBlockRegistry[item.kind];
  if (builder == null) return _unsupported(item, ctx);
  return builder(item, ctx);
}
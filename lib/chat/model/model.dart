import 'package:flutter/widgets.dart';

enum ChatSender { bot, user }

enum ChatItemKind {
  text,
  image,
  divider,
  quiz,
  quizSummary,
  submission,
  submissionReview,
  submissionReward,
  video,
  choice,
  form,
  profileVerify,
  checkpoint,
  scorecard,
  nextActivity,
  loading,
  error;

  static ChatItemKind fromLegacyKey(String? key) => switch (key) {
    'text' || 'static' => ChatItemKind.text,
    'image' => ChatItemKind.image,
    'divider' => ChatItemKind.divider,
    'quiz_question' || 'quiz' => ChatItemKind.quiz,
    'quiz_summary' => ChatItemKind.quizSummary,
    'submission' || 'dynamic_submission' => ChatItemKind.submission,
    'submission_review' => ChatItemKind.submissionReview,
    'submission_reward' => ChatItemKind.submissionReward,
    'video' => ChatItemKind.video,
    'choice_cards' || 'choice_buttons' || 'choice' => ChatItemKind.choice,
    'form' => ChatItemKind.form,
    'profile_verify' => ChatItemKind.profileVerify,
    'skill_passport' || 'scorecard' => ChatItemKind.scorecard,
    'celebration' || 'checkpoint' => ChatItemKind.checkpoint,
    'next_activity' => ChatItemKind.nextActivity,
    'loading' => ChatItemKind.loading,
    _ => ChatItemKind.error,
  };
}

class ChatOption {
  const ChatOption({
    required this.key,
    required this.label,
    this.next,
    this.imagePath,
  });

  final String key;
  final String label;
  final String? next;
  final String? imagePath;

  ChatOption copyWith({
    String? key,
    String? label,
    String? next,
    String? imagePath,
  }) => ChatOption(
    key: key ?? this.key,
    label: label ?? this.label,
    next: next ?? this.next,
    imagePath: imagePath ?? this.imagePath,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatOption &&
      other.key == key &&
      other.label == label &&
      other.next == next &&
      other.imagePath == imagePath;

  @override
  int get hashCode => Object.hash(key, label, next, imagePath);
}

class ChatAudioRef {
  const ChatAudioRef({required this.audioId, this.path});

  final String audioId;
  final String? path;

  ChatAudioRef withPath(String? resolvedPath) =>
      ChatAudioRef(audioId: audioId, path: resolvedPath);

  @override
  bool operator ==(Object other) =>
      other is ChatAudioRef && other.audioId == audioId && other.path == path;

  @override
  int get hashCode => Object.hash(audioId, path);
}

class ChatVariables {
  ChatVariables([Map<String, Object?>? initial])
    : _values = Map<String, Object?>.from(initial ?? const {});

  final Map<String, Object?> _values;

  Object? operator [](String key) => _values[key];

  void operator []=(String key, Object? value) {
    _values[key] = value;
  }

  int get quizIndex => (_values['quizIndex'] as num?)?.toInt() ?? 0;

  set quizIndex(int value) => _values['quizIndex'] = value;

  bool containsKey(String key) => _values.containsKey(key);

  Map<String, Object?> toMap() => Map<String, Object?>.from(_values);

  void addAll(Map<String, Object?> values) => _values.addAll(values);
}

sealed class ChatItem {
  const ChatItem({
    required this.id,
    required this.stepId,
    required this.kind,
    required this.sender,
    this.text,
    this.audio,
    this.isMuted = false,
    this.meta = const {},
  });

  final String id;
  final String stepId;
  final ChatItemKind kind;
  final ChatSender sender;
  final String? text;
  final ChatAudioRef? audio;
  final bool isMuted;
  final Map<String, Object?> meta;
}

class TextItem extends ChatItem {
  const TextItem({
    required super.id,
    required super.stepId,
    required super.sender,
    super.text,
    super.audio,
    super.isMuted,
    super.meta,
  }) : super(kind: ChatItemKind.text);
}

class ImageItem extends ChatItem {
  const ImageItem({
    required super.id,
    required super.stepId,
    required super.sender,
    required this.src,
    this.caption,
    this.alt,
    super.audio,
    super.meta,
  }) : super(kind: ChatItemKind.image, text: caption);

  final String src;
  final String? caption;
  final String? alt;
}

class DividerItem extends ChatItem {
  const DividerItem({
    required super.id,
    required super.stepId,
    required this.label,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.divider,
         sender: ChatSender.bot,
         text: label,
       );

  final String label;
}

class QuizItem extends ChatItem {
  const QuizItem({
    required super.id,
    required super.stepId,
    required this.questionIndex,
    required this.totalQuestions,
    required this.question,
    required this.options,
    required this.answerKey,
    this.hint,
    this.explanation,
    this.points = 0,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.quiz,
         sender: ChatSender.bot,
         text: question,
       );

  final int questionIndex;
  final int totalQuestions;
  final String question;
  final List<ChatOption> options;
  final String answerKey;
  final String? hint;
  final String? explanation;
  final int points;
}

class QuizSummaryItem extends ChatItem {
  const QuizSummaryItem({
    required super.id,
    required super.stepId,
    required this.correct,
    required this.total,
    super.text,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.quizSummary,
         sender: ChatSender.bot,
       );

  final int correct;
  final int total;
}

class SubmissionItem extends ChatItem {
  const SubmissionItem({
    required super.id,
    required super.stepId,
    required this.assignmentName,
    required this.assignmentDesc,
    required this.guidedText,
    required this.unguidedText,
    required this.subTypes,
    required this.validCriteria,
    required this.submissionKind,
    required this.points,
    required this.stepNumber,
    required this.stepTotal,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.submission,
         sender: ChatSender.bot,
         text: guidedText,
       );

  final String assignmentName;
  final String assignmentDesc;
  final String? guidedText;
  final String unguidedText;
  final String subTypes;
  final String? validCriteria;
  final String submissionKind;
  final int points;
  final int stepNumber;
  final int stepTotal;
}

class SubmissionReviewItem extends ChatItem {
  const SubmissionReviewItem({
    required super.id,
    required super.stepId,
    required this.score,
    required this.passed,
    required this.feedback,
    required this.strengths,
    required this.improvements,
    required this.smsText,
    required this.isFinalStep,
    super.text,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.submissionReview,
         sender: ChatSender.bot,
       );

  final int? score;
  final bool passed;
  final String? feedback;
  final List<String> strengths;
  final List<String> improvements;
  final String? smsText;
  final bool isFinalStep;
}

class SubmissionRewardItem extends ChatItem {
  const SubmissionRewardItem({
    required super.id,
    required super.stepId,
    required this.studentName,
    required this.points,
    super.text,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.submissionReward,
         sender: ChatSender.bot,
       );

  final String studentName;
  final int points;
}

class VideoItem extends ChatItem {
  const VideoItem({
    required super.id,
    required super.stepId,
    required this.videoId,
    required this.title,
    required this.description,
    required this.youtubeId,
    required this.points,
    this.watched = false,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.video,
         sender: ChatSender.bot,
       );

  final String videoId;
  final String title;
  final String description;
  final String youtubeId;
  final int points;
  final bool watched;

  VideoItem copyWith({bool? watched}) => VideoItem(
    id: id,
    stepId: stepId,
    videoId: videoId,
    title: title,
    description: description,
    youtubeId: youtubeId,
    points: points,
    watched: watched ?? this.watched,
    audio: audio,
    meta: meta,
  );
}

class ChoiceItem extends ChatItem {
  const ChoiceItem({
    required super.id,
    required super.stepId,
    required this.layout,
    required this.options,
    super.text,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.choice,
         sender: ChatSender.bot,
       );

  final String layout;
  final List<ChatOption> options;
}

class ChatFormField {
  const ChatFormField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
  });

  final String key;
  final String label;
  final String type;
  final bool required;
  final List<ChatOption> options;
}

class FormItem extends ChatItem {
  const FormItem({
    required super.id,
    required super.stepId,
    required this.fields,
    super.text,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.form,
         sender: ChatSender.bot,
       );

  final List<ChatFormField> fields;
}

class ProfileVerifyItem extends ChatItem {
  const ProfileVerifyItem({
    required super.id,
    required super.stepId,
    required this.fields,
    required this.editable,
    super.text,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.profileVerify,
         sender: ChatSender.bot,
       );

  final Map<String, String> fields;
  final bool editable;
}

class CheckpointItem extends ChatItem {
  const CheckpointItem({
    required super.id,
    required super.stepId,
    required this.mode,
    required this.buttonLabel,
    required this.action,
    this.image,
    this.sectionKind = 'generic',
    super.text,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.checkpoint,
         sender: ChatSender.bot,
       );

  final String mode;
  final String? image;
  final String buttonLabel;
  final String action;
  final String sectionKind;
}

class ScoreRow {
  const ScoreRow({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;
}

class ScorecardItem extends ChatItem {
  const ScorecardItem({
    required super.id,
    required super.stepId,
    required this.rows,
    this.total,
    super.text,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.scorecard,
         sender: ChatSender.bot,
       );

  final List<ScoreRow> rows;
  final String? total;
}

class NextActivityItem extends ChatItem {
  const NextActivityItem({
    required super.id,
    required super.stepId,
    required this.courseDisplay,
    required this.unitName,
    required this.points,
    required this.streak,
    required this.gems,
    required this.hasNextUnit,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.nextActivity,
         sender: ChatSender.bot,
       );

  final String courseDisplay;
  final String unitName;
  final int points;
  final int streak;
  final int gems;
  final bool hasNextUnit;
}

class LoadingItem extends ChatItem {
  const LoadingItem({required super.id, required super.stepId})
    : super(
        kind: ChatItemKind.loading,
        sender: ChatSender.bot,
      );
}

class ErrorItem extends ChatItem {
  const ErrorItem({
    required super.id,
    required super.stepId,
    required this.message,
    this.retryAction,
    super.audio,
    super.meta,
  }) : super(
         kind: ChatItemKind.error,
         sender: ChatSender.bot,
         text: message,
       );

  final String message;
  final String? retryAction;
}
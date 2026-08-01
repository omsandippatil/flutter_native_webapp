/// The kind of input widget the submission step needs, derived from the
/// course JSON's `sub_types` field (e.g. "emoji", "text,audio", "image",
/// "image,video").
enum SubmissionKind { emoji, text, audio, textAudio, image, video, imageVideo }

class SubmissionAnswer {
  const SubmissionAnswer._({
    required this.kind,
    this.text,
    this.emoji,
    this.mediaPath,
  });

  final SubmissionKind kind;
  final String? text;
  final String? emoji;
  final String? mediaPath;

  factory SubmissionAnswer.emoji(String emoji) =>
      SubmissionAnswer._(kind: SubmissionKind.emoji, emoji: emoji);

  factory SubmissionAnswer.text(String text) =>
      SubmissionAnswer._(kind: SubmissionKind.text, text: text);

  factory SubmissionAnswer.audioTranscript(String text) =>
      SubmissionAnswer._(kind: SubmissionKind.textAudio, text: text);

  factory SubmissionAnswer.image(String path) =>
      SubmissionAnswer._(kind: SubmissionKind.image, mediaPath: path);

  factory SubmissionAnswer.video(String path) =>
      SubmissionAnswer._(kind: SubmissionKind.video, mediaPath: path);

  factory SubmissionAnswer.imageOrVideo(String path, {required bool isVideo}) =>
      SubmissionAnswer._(kind: SubmissionKind.imageVideo, mediaPath: path);

  /// A short, human-readable echo of what was submitted, for the chat
  /// bubble that shows what the *user* sent (never a form).
  String get displaySummary {
    switch (kind) {
      case SubmissionKind.emoji:
        return emoji ?? '';
      case SubmissionKind.text:
      case SubmissionKind.textAudio:
        return text ?? '';
      case SubmissionKind.audio:
        return text ?? '🎤 Voice note';
      case SubmissionKind.image:
        return '📷 Photo submitted';
      case SubmissionKind.video:
        return '🎥 Video submitted';
      case SubmissionKind.imageVideo:
        return mediaPath != null && mediaPath!.toLowerCase().endsWith('.mp4')
            ? '🎥 Video submitted'
            : '📷 Photo submitted';
    }
  }

  /// Simple local matching against a step's `valid_criteria` for kinds that
  /// don't need an AI review (emoji / short fixed-vocabulary text answers).
  /// Case-insensitive, comma-or-"or"-separated criteria list.
  bool matchesCriteria(String? validCriteria) {
    if (validCriteria == null || validCriteria.trim().isEmpty) return true;

    final candidates = validCriteria
        .toLowerCase()
        .split(RegExp(r'\s*(?:,| or )\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (kind == SubmissionKind.emoji) {
      final value = (emoji ?? '').trim();
      return candidates.any((c) => value.contains(c) || c.contains(value));
    }

    final value = (text ?? '').trim().toLowerCase();
    if (value.isEmpty) return false;
    return candidates.any((c) => value == c || value.contains(c));
  }
}

class SubmissionKindResolver {
  SubmissionKindResolver._();

  /// Parses the course JSON's `sub_types` string (e.g. "text,audio",
  /// "image,video", "emoji", "image") into a [SubmissionKind].
  static SubmissionKind fromSubTypes(String subTypes) {
    final normalized = subTypes.toLowerCase();
    final hasEmoji = normalized.contains('emoji');
    final hasText = normalized.contains('text');
    final hasAudio = normalized.contains('audio');
    final hasImage = normalized.contains('image');
    final hasVideo = normalized.contains('video');

    if (hasEmoji) return SubmissionKind.emoji;
    if (hasImage && hasVideo) return SubmissionKind.imageVideo;
    if (hasImage) return SubmissionKind.image;
    if (hasVideo) return SubmissionKind.video;
    if (hasText && hasAudio) return SubmissionKind.textAudio;
    if (hasAudio) return SubmissionKind.audio;
    return SubmissionKind.text;
  }

  /// Whether this kind needs an AI-graded review (open-ended text/audio,
  /// image, video) versus simple local criteria matching (emoji, fixed
  /// vocabulary word/voice answers already handled by hardcoded replies).
  static bool requiresAiReview(SubmissionKind kind) {
    switch (kind) {
      case SubmissionKind.emoji:
        return false;
      case SubmissionKind.text:
      case SubmissionKind.textAudio:
      case SubmissionKind.audio:
      case SubmissionKind.image:
      case SubmissionKind.video:
      case SubmissionKind.imageVideo:
        return true;
    }
  }

  static String aiSubmissionType(SubmissionKind kind) {
    switch (kind) {
      case SubmissionKind.emoji:
        return 'emoji';
      case SubmissionKind.text:
        return 'text';
      case SubmissionKind.textAudio:
        return 'text_audio';
      case SubmissionKind.audio:
        return 'audio';
      case SubmissionKind.image:
        return 'image';
      case SubmissionKind.video:
        return 'video';
      case SubmissionKind.imageVideo:
        return 'image_video';
    }
  }
}

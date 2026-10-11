enum SubmissionKind { emoji, text, audio, textAudio, image, video, imageVideo }

extension SubmissionKindWire on SubmissionKind {
  String get wireValue => switch (this) {
    SubmissionKind.emoji => 'emoji',
    SubmissionKind.text => 'text',
    SubmissionKind.audio => 'audio',
    SubmissionKind.textAudio => 'textAudio',
    SubmissionKind.image => 'image',
    SubmissionKind.video => 'video',
    SubmissionKind.imageVideo => 'imageVideo',
  };

  static SubmissionKind fromWire(String value) => switch (value) {
    'emoji' => SubmissionKind.emoji,
    'text' => SubmissionKind.text,
    'audio' => SubmissionKind.audio,
    'textAudio' => SubmissionKind.textAudio,
    'image' => SubmissionKind.image,
    'video' => SubmissionKind.video,
    'imageVideo' => SubmissionKind.imageVideo,
    _ => SubmissionKind.text,
  };
}

class SubmissionKindResolver {
  SubmissionKindResolver._();

  static SubmissionKind fromWire(String value) =>
      SubmissionKindWire.fromWire(value);

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

  static bool requiresAiReview(SubmissionKind kind) =>
      kind != SubmissionKind.emoji;

  static bool isMedia(SubmissionKind kind) =>
      kind == SubmissionKind.image ||
      kind == SubmissionKind.video ||
      kind == SubmissionKind.imageVideo;
}

class SubmissionAnswer {
  const SubmissionAnswer._({
    required this.kind,
    this.text,
    this.emoji,
    this.mediaPath,
    this.isVideo = false,
  });

  final SubmissionKind kind;
  final String? text;
  final String? emoji;
  final String? mediaPath;
  final bool isVideo;

  factory SubmissionAnswer.emoji(String emoji) =>
      SubmissionAnswer._(kind: SubmissionKind.emoji, emoji: emoji);

  factory SubmissionAnswer.text(String text) =>
      SubmissionAnswer._(kind: SubmissionKind.text, text: text);

  factory SubmissionAnswer.audioTranscript(String text) =>
      SubmissionAnswer._(kind: SubmissionKind.textAudio, text: text);

  factory SubmissionAnswer.image(String path) =>
      SubmissionAnswer._(kind: SubmissionKind.image, mediaPath: path);

  factory SubmissionAnswer.video(String path) => SubmissionAnswer._(
    kind: SubmissionKind.video,
    mediaPath: path,
    isVideo: true,
  );

  factory SubmissionAnswer.imageOrVideo(
    String path, {
    required bool isVideo,
  }) => SubmissionAnswer._(
    kind: isVideo ? SubmissionKind.video : SubmissionKind.image,
    mediaPath: path,
    isVideo: isVideo,
  );

  Map<String, Object?> toPayload() => {
    'kind': kind.wireValue,
    'text': text,
    'emoji': emoji,
    'mediaPath': mediaPath,
    'isVideo': isVideo,
  };

  bool matchesCriteria(String? validCriteria) {
    if (validCriteria == null || validCriteria.trim().isEmpty) return true;

    final candidates = validCriteria
        .toLowerCase()
        .split(RegExp(r'\s*(?:,|/| or )\s*'))
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

class SubmissionKindDisplay {
  const SubmissionKindDisplay({
    required this.label,
    this.icon,
    this.emojiChoices = const [],
    this.friendLabel = 'See what friends made',
  });

  final String label;
  final String? icon;
  final List<String> emojiChoices;
  final String friendLabel;

  factory SubmissionKindDisplay.fromJson(Map<String, dynamic> json) =>
      SubmissionKindDisplay(
        label: json['label'] as String? ?? '',
        icon: json['icon'] as String?,
        emojiChoices:
            (json['emoji_choices'] as List?)?.whereType<String>().toList() ??
            const [],
        friendLabel: json['friend_label'] as String? ?? 'See what friends made',
      );
}

class SubmissionFriendExample {
  const SubmissionFriendExample({
    required this.preview,
    this.mediaUrl,
    this.isVideo = false,
  });

  final String preview;
  final String? mediaUrl;
  final bool isVideo;

  factory SubmissionFriendExample.fromJson(Map<String, dynamic> json) =>
      SubmissionFriendExample(
        preview: json['preview'] as String? ?? '',
        mediaUrl: json['media_url'] as String?,
        isVideo: json['is_video'] as bool? ?? false,
      );
}

class SubmissionContent {
  const SubmissionContent({
    required this.display,
    this.friendExamples = const [],
  });

  final SubmissionKindDisplay display;
  final List<SubmissionFriendExample> friendExamples;

  factory SubmissionContent.fromJson(Map<String, dynamic> json) =>
      SubmissionContent(
        display: json['display'] is Map
            ? SubmissionKindDisplay.fromJson(
                Map<String, dynamic>.from(json['display'] as Map),
              )
            : const SubmissionKindDisplay(label: ''),
        friendExamples: (json['friend_examples'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (m) => SubmissionFriendExample.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList(growable: false),
      );

  static SubmissionContent empty(SubmissionKind kind) => SubmissionContent(
    display: SubmissionKindDisplay(label: kind.wireValue),
  );
}

typedef SubmissionContentFetcher =
    Future<SubmissionContent> Function({
      required String stepId,
      required SubmissionKind kind,
    });

class SubmissionContentCache {
  SubmissionContentCache._();

  static final Map<String, Future<SubmissionContent>> _inFlight = {};
  static final Map<String, SubmissionContent> _resolved = {};

  static String _key(String stepId, SubmissionKind kind) =>
      '$stepId:${kind.wireValue}';

  static Future<SubmissionContent> fetch({
    required String stepId,
    required SubmissionKind kind,
    required SubmissionContentFetcher? fetcher,
  }) {
    if (fetcher == null) {
      return Future.value(SubmissionContent.empty(kind));
    }

    final key = _key(stepId, kind);
    final cached = _resolved[key];
    if (cached != null) return Future.value(cached);

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = fetcher(stepId: stepId, kind: kind)
        .then((content) {
          _resolved[key] = content;
          _inFlight.remove(key);
          return content;
        })
        .catchError((Object error) {
          _inFlight.remove(key);
          throw error;
        });

    _inFlight[key] = future;
    return future;
  }

  static void invalidate(String stepId, SubmissionKind kind) {
    _resolved.remove(_key(stepId, kind));
    _inFlight.remove(_key(stepId, kind));
  }

  static void clear() {
    _resolved.clear();
    _inFlight.clear();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapapp/core/learner/learner.dart';
import 'package:tapapp/core/network/network.dart';
import 'package:tapapp/core/profile/profile.dart';
import 'package:tapapp/core/providers.dart';
import 'package:tapapp/core/storage/storage.dart';
import 'package:tapapp/features/classroom/classroom.dart';

class ChatTurnModel {
  const ChatTurnModel({required this.role, required this.content});

  final String role;
  final String content;

  factory ChatTurnModel.user(String content) =>
      ChatTurnModel(role: 'user', content: content);
  factory ChatTurnModel.assistant(String content) =>
      ChatTurnModel(role: 'assistant', content: content);

  factory ChatTurnModel.fromJson(Map<String, dynamic> json) => ChatTurnModel(
    role: json['role'] as String? ?? 'user',
    content: json['content'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  static List<ChatTurnModel> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ChatTurnModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> listToJson(List<ChatTurnModel> list) =>
      list.map((t) => t.toJson()).toList(growable: false);
}

class TapbuddyChatRepository {
  TapbuddyChatRepository(this._http, this._localCache);

  final HttpClient _http;
  final LocalCache _localCache;

  static const int _maxHistoryMessages = 12;

  Future<List<ChatTurnModel>> readTranscript(
    String phone,
    String learnerId,
  ) async {
    final raw = _localCache.getForeverList(
      CacheKeys.chatTranscript(phone, learnerId),
      (json) => json,
    );
    return raw == null ? const [] : ChatTurnModel.listFromJson(raw);
  }

  Future<String> sendMessage({
    required String phone,
    required String learnerId,
    required String message,
    String? grade,
    String? language,
    Map<String, dynamic>? context,
  }) async {
    final key = CacheKeys.chatTranscript(phone, learnerId);
    final history = await readTranscript(phone, learnerId);
    final recentHistory = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;

    final data = await _http.post(
      ApiEndpoints.tapbuddyChat,
      body: {
        'phone': phone,
        'learner_id': learnerId,
        'message': message,
        'grade': ?grade,
        'language': ?language,
        if (context != null && context.isNotEmpty)
          'context': context,
        'history': ChatTurnModel.listToJson(recentHistory),
      },
    );

    final reply = data['reply'] as String? ?? '';

    final updated = [
      ...history,
      ChatTurnModel.user(message),
      ChatTurnModel.assistant(reply),
    ];
    await _localCache.setForeverRawList(key, ChatTurnModel.listToJson(updated));

    return reply;
  }

  Future<void> clearTranscript(String phone, String learnerId) async {
    await _localCache.delete(CacheKeys.chatTranscript(phone, learnerId));
  }
}

final tapbuddyChatRepositoryProvider = FutureProvider<TapbuddyChatRepository>((
  ref,
) async {
  final localCache = await ref.watch(localCacheProvider.future);
  return TapbuddyChatRepository(ref.watch(httpClientProvider), localCache);
});

class ChatTranscriptRequest {
  const ChatTranscriptRequest({required this.phone, required this.learnerId});
  final String phone;
  final String learnerId;

  @override
  bool operator ==(Object other) =>
      other is ChatTranscriptRequest &&
      other.phone == phone &&
      other.learnerId == learnerId;

  @override
  int get hashCode => Object.hash(phone, learnerId);
}

final chatTranscriptDataProvider = FutureProvider.autoDispose
    .family<List<ChatTurnModel>, ChatTranscriptRequest>((ref, request) async {
      final repository = await ref.watch(tapbuddyChatRepositoryProvider.future);
      return repository.readTranscript(request.phone, request.learnerId);
    });

class TapBuddyContext {
  const TapBuddyContext({
    this.studentName,
    this.grade,
    this.courseName,
    this.unitName,
    this.unitDescription,
    this.xp,
    this.streak,
    this.hasReachedWeeklyCap = false,
    this.hasActiveClassSession = false,
  });

  final String? studentName;
  final String? grade;
  final String? courseName;
  final String? unitName;
  final String? unitDescription;
  final int? xp;
  final int? streak;
  final bool hasReachedWeeklyCap;
  final bool hasActiveClassSession;

  Map<String, dynamic> toJson() => {
    if (studentName != null)
      'student_name': studentName,
    if (grade != null)
      'grade': grade,
    if (courseName != null)
      'course_name': courseName,
    if (unitName != null)
      'unit_name': unitName,
    if (unitDescription != null)
      'unit_description':
          unitDescription,
    if (xp != null) 'xp': xp,
    if (streak != null)
      'streak': streak,
    'has_reached_weekly_cap': hasReachedWeeklyCap,
    'has_active_class_session': hasActiveClassSession,
  };
}

final tapBuddyContextProvider = FutureProvider.autoDispose<TapBuddyContext>((
  ref,
) async {
  final activeProfile = await ref.watch(activeProfileProvider.future);
  if (activeProfile == null) return const TapBuddyContext();

  LearnerStateModel? learnerState;
  try {
    learnerState = await ref.watch(
      learnerStateDataProvider(activeProfile.learnerId).future,
    );
  } catch (_) {
    learnerState = null;
  }

  try {
    final bootstrap = await ref.watch(classSessionBootstrapProvider.future);
    return TapBuddyContext(
      studentName:
          bootstrap.learnerState.profile?.studentName ??
          activeProfile.studentName,
      grade: activeProfile.grade,
      courseName: bootstrap.courseName,
      unitName: bootstrap.unit?.name,
      unitDescription: bootstrap.unit?.description,
      xp: bootstrap.learnerState.xp,
      streak: bootstrap.learnerState.streak,
      hasReachedWeeklyCap: bootstrap.weeklyCapAlreadyReached,
      hasActiveClassSession: bootstrap.unit != null,
    );
  } catch (_) {
    return TapBuddyContext(
      studentName:
          learnerState?.profile?.studentName ?? activeProfile.studentName,
      grade: activeProfile.grade,
      courseName: learnerState?.enrollment?.course,
      xp: learnerState?.xp,
      streak: learnerState?.streak,
      hasReachedWeeklyCap:
          learnerState?.hasReachedWeeklyActivityLimit() ?? false,
      hasActiveClassSession: false,
    );
  }
});

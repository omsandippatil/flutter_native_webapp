import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapapp/core/network/network.dart';
import 'package:tapapp/core/providers.dart';
import 'package:tapapp/core/storage/storage.dart';

const List<String> completedUnitStateFields = [
  'videos_completed',
  'submission_index',
  'quizzes_completed',
];

class LearnerArchetype {
  static const String dormant = 'dormant';
  static const String fenceSitter = 'fence_sitter';
  static const String irregularSubmitter = 'irregular_submitter';
  static const String submitter = 'submitter';
  static const String activeSubmitter = 'active_submitter';

  static String normalize(String? raw) {
    if (raw == null || raw.isEmpty) return dormant;
    final lower = raw.toLowerCase().replaceAll(' ', '_');
    const known = [dormant, fenceSitter, irregularSubmitter, submitter, activeSubmitter];
    for (final k in known) {
      if (lower == k) return k;
    }
    return dormant;
  }
}

class AchievementModel {
  const AchievementModel({required this.id, required this.unlockedAt});
  final String id;
  final String unlockedAt;

  factory AchievementModel.fromJson(Map<String, dynamic> j) =>
      AchievementModel(id: j['id'] as String? ?? '', unlockedAt: j['unlocked_at'] as String? ?? '');
  Map<String, dynamic> toJson() => {'id': id, 'unlocked_at': unlockedAt};
}

class EnrollmentModel {
  const EnrollmentModel({
    this.course,
    this.videosCompleted = 0,
    this.submissionIndex = 0,
    this.quizzesCompleted = 0,
    this.enrolledAt,
  });

  final String? course;
  final int videosCompleted;
  final int submissionIndex;
  final int quizzesCompleted;
  final String? enrolledAt;

  factory EnrollmentModel.fromJson(Map<String, dynamic> j) => EnrollmentModel(
    course: j['course'] as String?,
    videosCompleted: (j['videos_completed'] as num?)?.toInt() ?? 0,
    submissionIndex: (j['submission_index'] as num?)?.toInt() ?? 0,
    quizzesCompleted: (j['quizzes_completed'] as num?)?.toInt() ?? 0,
    enrolledAt: j['enrolled_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'course': course,
    'videos_completed': videosCompleted,
    'submission_index': submissionIndex,
    'quizzes_completed': quizzesCompleted,
    'enrolled_at': enrolledAt,
  };

  EnrollmentModel copyWith({
    String? course,
    int? videosCompleted,
    int? submissionIndex,
    int? quizzesCompleted,
  }) => EnrollmentModel(
    course: course ?? this.course,
    videosCompleted: videosCompleted ?? this.videosCompleted,
    submissionIndex: submissionIndex ?? this.submissionIndex,
    quizzesCompleted: quizzesCompleted ?? this.quizzesCompleted,
    enrolledAt: enrolledAt,
  );
}

class LearnerProfileFieldsModel {
  const LearnerProfileFieldsModel({
    this.studentName,
    this.language,
    this.schoolName,
    this.schoolCode,
  });

  final String? studentName;
  final String? language;
  final String? schoolName;
  final String? schoolCode;

  factory LearnerProfileFieldsModel.fromJson(Map<String, dynamic> j) =>
      LearnerProfileFieldsModel(
        studentName: j['student_name'] as String?,
        language: j['language'] as String?,
        schoolName: j['school_name'] as String?,
        schoolCode: j['school_code'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'student_name': studentName,
    'language': language,
    'school_name': schoolName,
    'school_code': schoolCode,
  };
}

class LearnerStateWeeklyLimit {
  static const int defaultWeeklyLimit = 1;
}

class LearnerStateModel {
  LearnerStateModel({
    required this.learnerId,
    this.profile,
    this.enrollment,
    this.xp,
    this.streak,
    this.submissionGems,
    this.submissionIndex,
    this.videosCompleted,
    this.quizzesCompleted,
    this.weeklyActivityCount,
    this.weeklyActivityLimit,
    this.windowStartDate,
    this.windowResetsOn,
    this.lastActivityDate,
    this.achievements = const [],
    this.pendingProgressXp = 0,
    this.hasPendingLocalProgress = false,
    this.archetype,
    this.extraFields = const {},
  });

  final String learnerId;
  final LearnerProfileFieldsModel? profile;
  final EnrollmentModel? enrollment;
  final int? xp;
  final int? streak;
  final int? submissionGems;
  final int? submissionIndex;
  final int? videosCompleted;
  final int? quizzesCompleted;
  final int? weeklyActivityCount;
  final int? weeklyActivityLimit;
  final String? windowStartDate;
  final String? windowResetsOn;
  final String? lastActivityDate;
  final List<AchievementModel> achievements;
  final int pendingProgressXp;
  final bool hasPendingLocalProgress;
  String? archetype;
  final Map<String, dynamic> extraFields;

  bool hasReachedWeeklyActivityLimit({int localCompleted = 0}) {
    final limit = weeklyActivityLimit ?? LearnerStateWeeklyLimit.defaultWeeklyLimit;
    final serverCount = weeklyActivityCount ?? 0;
    return (serverCount + localCompleted) >= limit;
  }

  factory LearnerStateModel.fromFullJson(String learnerId, Map<String, dynamic> j) {
    final profileRaw = j['profile'];
    final enrollmentRaw = j['enrollment'];
    final achievementsRaw = j['achievements'];
    return LearnerStateModel(
      learnerId: learnerId,
      profile: profileRaw is Map
          ? LearnerProfileFieldsModel.fromJson(Map<String, dynamic>.from(profileRaw))
          : null,
      enrollment: enrollmentRaw is Map
          ? EnrollmentModel.fromJson(Map<String, dynamic>.from(enrollmentRaw))
          : null,
      xp: (j['xp'] as num?)?.toInt(),
      streak: (j['streak'] as num?)?.toInt(),
      submissionGems: (j['submission_gems'] as num?)?.toInt(),
      submissionIndex: (j['submission_index'] as num?)?.toInt(),
      videosCompleted: (j['videos_completed'] as num?)?.toInt(),
      quizzesCompleted: (j['quizzes_completed'] as num?)?.toInt(),
      weeklyActivityCount: (j['weekly_activity_count'] as num?)?.toInt(),
      weeklyActivityLimit: (j['weekly_activity_limit'] as num?)?.toInt(),
      windowStartDate: j['window_start_date'] as String?,
      windowResetsOn: j['window_resets_on'] as String?,
      lastActivityDate: j['last_activity_date'] as String?,
      achievements: achievementsRaw is List
          ? achievementsRaw.whereType<Map>().map((m) => AchievementModel.fromJson(Map<String, dynamic>.from(m))).toList()
          : const [],
      archetype: j['archetype'] as String?,
      pendingProgressXp: (j['pending_progress_xp'] as num?)?.toInt() ?? 0,
      hasPendingLocalProgress: j['has_pending_local_progress'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'learner_id': learnerId,
    'profile': profile?.toJson(),
    'enrollment': enrollment?.toJson(),
    'xp': xp,
    'streak': streak,
    'submission_gems': submissionGems,
    'submission_index': submissionIndex,
    'videos_completed': videosCompleted,
    'quizzes_completed': quizzesCompleted,
    'weekly_activity_count': weeklyActivityCount,
    'weekly_activity_limit': weeklyActivityLimit,
    'window_start_date': windowStartDate,
    'window_resets_on': windowResetsOn,
    'last_activity_date': lastActivityDate,
    'achievements': achievements.map((a) => a.toJson()).toList(),
    'archetype': archetype,
    'pending_progress_xp': pendingProgressXp,
    'has_pending_local_progress': hasPendingLocalProgress,
  };

  LearnerStateModel mergeFrom(Map<String, dynamic> j) {
    final profileRaw = j['profile'];
    final enrollmentRaw = j['enrollment'];
    return LearnerStateModel(
      learnerId: learnerId,
      profile: profileRaw is Map
          ? LearnerProfileFieldsModel.fromJson(Map<String, dynamic>.from(profileRaw))
          : profile,
      enrollment: enrollmentRaw is Map
          ? EnrollmentModel.fromJson(Map<String, dynamic>.from(enrollmentRaw))
          : enrollment,
      xp: (j['xp'] as num?)?.toInt() ?? xp,
      streak: (j['streak'] as num?)?.toInt() ?? streak,
      submissionGems: (j['submission_gems'] as num?)?.toInt() ?? submissionGems,
      submissionIndex: (j['submission_index'] as num?)?.toInt() ?? submissionIndex,
      videosCompleted: (j['videos_completed'] as num?)?.toInt() ?? videosCompleted,
      quizzesCompleted: (j['quizzes_completed'] as num?)?.toInt() ?? quizzesCompleted,
      weeklyActivityCount: (j['weekly_activity_count'] as num?)?.toInt() ?? weeklyActivityCount,
      weeklyActivityLimit: (j['weekly_activity_limit'] as num?)?.toInt() ?? weeklyActivityLimit,
      windowStartDate: j['window_start_date'] as String? ?? windowStartDate,
      windowResetsOn: j['window_resets_on'] as String? ?? windowResetsOn,
      lastActivityDate: j['last_activity_date'] as String? ?? lastActivityDate,
      archetype: j['archetype'] as String? ?? archetype,
      pendingProgressXp: (j['pending_progress_xp'] as num?)?.toInt() ?? pendingProgressXp,
      hasPendingLocalProgress: j['has_pending_local_progress'] as bool? ?? hasPendingLocalProgress,
    );
  }
}

class LocalArchetypeCalculator {
  LocalArchetypeCalculator._();

  static String compute({
    required int streak,
    required int submissionCount,
    required String? lastActivityDate,
    required DateTime now,
  }) {
    if (submissionCount == 0 && streak == 0) return LearnerArchetype.dormant;
    if (streak == 0) return LearnerArchetype.fenceSitter;
    if (submissionCount >= 3 && streak >= 3) return LearnerArchetype.activeSubmitter;
    if (submissionCount >= 1) return LearnerArchetype.submitter;
    return LearnerArchetype.irregularSubmitter;
  }
}

class ProgressConflictException implements Exception {
  const ProgressConflictException([this.message]);
  final String? message;
  @override
  String toString() => 'ProgressConflictException: ${message ?? 'conflict'}';
}

class ProgressNotRecordedException implements Exception {
  const ProgressNotRecordedException([this.message]);
  final String? message;
  @override
  String toString() => 'ProgressNotRecordedException: ${message ?? 'not recorded'}';
}

class LearnerStateRepository {
  LearnerStateRepository(this._http, this._localCache);

  final HttpClient _http;
  final LocalCache _localCache;

  Future<LearnerStateModel?> readCached(String learnerId) async {
    final raw = _localCache.getForeverRaw(CacheKeys.learnerState(learnerId));
    if (raw == null) return null;
    try {
      return LearnerStateModel.fromFullJson(learnerId, raw);
    } catch (_) {
      return null;
    }
  }

  Future<LearnerStateModel> fetchState({
    required String learnerId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await readCached(learnerId);
      if (cached != null) return cached;
    }
    final data = await _http.get(
      ApiEndpoints.learnerState,
      query: {'learner_id': learnerId},
    );
    final model = LearnerStateModel.fromFullJson(learnerId, data);
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), model.toJson());
    return model;
  }

  Future<LearnerStateModel> cacheLocalProgress({
    required String learnerId,
    int xp = 0,
    int? videoIndex,
    int? submissionIndex,
    int? quizIndex,
  }) async {
    final existing = await readCached(learnerId) ??
        LearnerStateModel(learnerId: learnerId);
    final currentEnrollment = existing.enrollment ?? const EnrollmentModel();
    final updated = LearnerStateModel(
      learnerId: learnerId,
      profile: existing.profile,
      enrollment: currentEnrollment.copyWith(
        videosCompleted: videoIndex ?? currentEnrollment.videosCompleted,
        submissionIndex: submissionIndex ?? currentEnrollment.submissionIndex,
        quizzesCompleted: quizIndex ?? currentEnrollment.quizzesCompleted,
      ),
      xp: (existing.xp ?? 0) + xp,
      streak: existing.streak,
      submissionGems: existing.submissionGems,
      submissionIndex: submissionIndex ?? existing.submissionIndex,
      videosCompleted: videoIndex ?? existing.videosCompleted,
      quizzesCompleted: quizIndex ?? existing.quizzesCompleted,
      weeklyActivityCount: existing.weeklyActivityCount,
      weeklyActivityLimit: existing.weeklyActivityLimit,
      windowStartDate: existing.windowStartDate,
      windowResetsOn: existing.windowResetsOn,
      lastActivityDate: existing.lastActivityDate,
      achievements: existing.achievements,
      archetype: existing.archetype,
      pendingProgressXp: (existing.pendingProgressXp) + xp,
      hasPendingLocalProgress: true,
    );
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), updated.toJson());
    return updated;
  }

  Future<void> markLocalProgressReady(String learnerId) async {
    final existing = await readCached(learnerId);
    if (existing == null) return;
    final updated = LearnerStateModel(
      learnerId: existing.learnerId,
      profile: existing.profile,
      enrollment: existing.enrollment,
      xp: existing.xp,
      streak: existing.streak,
      submissionGems: existing.submissionGems,
      submissionIndex: existing.submissionIndex,
      videosCompleted: existing.videosCompleted,
      quizzesCompleted: existing.quizzesCompleted,
      weeklyActivityCount: existing.weeklyActivityCount,
      weeklyActivityLimit: existing.weeklyActivityLimit,
      windowStartDate: existing.windowStartDate,
      windowResetsOn: existing.windowResetsOn,
      lastActivityDate: existing.lastActivityDate,
      achievements: existing.achievements,
      archetype: existing.archetype,
      pendingProgressXp: existing.pendingProgressXp,
      hasPendingLocalProgress: true,
    );
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), updated.toJson());
  }

  Future<LearnerStateModel> submitProgress({
    required String learnerId,
    int? xp,
    String? activityType,
    int? videoIndex,
    int? quizIndex,
    int? submissionIndex,
    List<String>? fields,
  }) async {
    try {
      final data = await _http.post(
        ApiEndpoints.learnerSubmitProgress,
        body: {
          'learner_id': learnerId,
          if (xp != null) 'xp': xp,
          if (activityType != null) 'activity_type': activityType,
          if (videoIndex != null) 'video_index': videoIndex,
          if (quizIndex != null) 'quiz_index': quizIndex,
          if (submissionIndex != null) 'submission_index': submissionIndex,
          if (fields != null) 'fields': fields,
        },
      );
      if (data['conflict'] == true) throw const ProgressConflictException();
      final model = LearnerStateModel.fromFullJson(learnerId, data);
      final cleared = LearnerStateModel(
        learnerId: model.learnerId,
        profile: model.profile,
        enrollment: model.enrollment,
        xp: model.xp,
        streak: model.streak,
        submissionGems: model.submissionGems,
        submissionIndex: model.submissionIndex,
        videosCompleted: model.videosCompleted,
        quizzesCompleted: model.quizzesCompleted,
        weeklyActivityCount: model.weeklyActivityCount,
        weeklyActivityLimit: model.weeklyActivityLimit,
        windowStartDate: model.windowStartDate,
        windowResetsOn: model.windowResetsOn,
        lastActivityDate: model.lastActivityDate,
        achievements: model.achievements,
        archetype: model.archetype,
        pendingProgressXp: 0,
        hasPendingLocalProgress: false,
      );
      await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), cleared.toJson());
      return cleared;
    } on ProgressConflictException {
      rethrow;
    } catch (e) {
      throw ProgressNotRecordedException(e.toString());
    }
  }

  Future<LearnerStateModel?> syncCompletedLocalProgress(String learnerId) async {
    final existing = await readCached(learnerId);
    if (existing == null || !existing.hasPendingLocalProgress) return null;
    try {
      return await submitProgress(
        learnerId: learnerId,
        xp: existing.pendingProgressXp > 0 ? existing.pendingProgressXp : null,
        activityType: 'sync',
      );
    } catch (_) {
      return null;
    }
  }

  Future<LearnerStateModel> prepareLocalUnit({
    required String learnerId,
    required int unitIndex,
  }) async {
    final existing = await readCached(learnerId) ??
        LearnerStateModel(learnerId: learnerId);
    final currentEnrollment = existing.enrollment ?? const EnrollmentModel();
    final updated = LearnerStateModel(
      learnerId: learnerId,
      profile: existing.profile,
      enrollment: currentEnrollment,
      xp: existing.xp,
      streak: existing.streak,
      submissionGems: existing.submissionGems,
      submissionIndex: unitIndex,
      videosCompleted: existing.videosCompleted,
      quizzesCompleted: existing.quizzesCompleted,
      weeklyActivityCount: existing.weeklyActivityCount,
      weeklyActivityLimit: existing.weeklyActivityLimit,
      windowStartDate: existing.windowStartDate,
      windowResetsOn: existing.windowResetsOn,
      lastActivityDate: existing.lastActivityDate,
      achievements: existing.achievements,
      archetype: existing.archetype,
      pendingProgressXp: 0,
      hasPendingLocalProgress: false,
    );
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), updated.toJson());
    return updated;
  }

  LearnerStateModel restoreLocalProgress(LearnerStateModel serverState) => serverState;

  Future<void> showHomeCelebration(String learnerId, {required int points}) async {
    await _localCache.setForeverRaw(
      'v2:home:celebration:$learnerId',
      {'show': true, 'points': points},
    );
  }

  Future<void> clearHomeCelebration(String learnerId) async {
    await _localCache.setForeverRaw('v2:home:celebration:$learnerId', {'show': false, 'points': 0});
  }

  Map<String, dynamic>? readHomeCelebration(String learnerId) =>
      _localCache.getForeverRaw('v2:home:celebration:$learnerId');
}

final learnerStateRepositoryProvider = FutureProvider<LearnerStateRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  return LearnerStateRepository(ref.watch(httpClientProvider), localCache);
});

final learnerStateDataProvider = FutureProvider.autoDispose.family<LearnerStateModel, String>((ref, learnerId) async {
  final repo = await ref.watch(learnerStateRepositoryProvider.future);
  return repo.fetchState(learnerId: learnerId);
});

Future<void> refreshLearnerState(WidgetRef ref, String learnerId) async {
  ref.invalidate(learnerStateDataProvider(learnerId));
}
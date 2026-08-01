import '../../core/cache/cache_keys.dart';
import '../../core/cache/local_cache.dart';
import '../../models/learner_state_model.dart';
import '../remote/api_endpoints.dart';
import '../remote/http_client.dart';

class ProgressConflictException implements Exception {
  ProgressConflictException(this.responseBody);
  final Map<String, dynamic> responseBody;

  @override
  String toString() =>
      'ProgressConflictException(learner progress write was rejected — local state left untouched)';
}

class ProgressNotRecordedException implements Exception {
  ProgressNotRecordedException(this.responseBody);
  final Map<String, dynamic> responseBody;

  @override
  String toString() =>
      'ProgressNotRecordedException(learner progress write was not recorded)';
}

class LearnerStateRepository {
  LearnerStateRepository(this._http, this._localCache);

  final HttpClient _http;
  final LocalCache _localCache;

  Future<LearnerStateModel?> readCached(String learnerId) async {
    final raw = _localCache.getForeverRaw(CacheKeys.learnerState(learnerId));
    if (raw == null) return null;
    return LearnerStateModel.fromCache(raw);
  }

  Future<LearnerStateModel> fetchState({
    required String learnerId,
    String? fields,
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

    return _writeFull(learnerId, data);
  }

  Future<LearnerStateModel> enrollCourse({
    required String learnerId,
    required String course,
  }) async {
    final data = await _http.post(
      ApiEndpoints.learnerEnroll,
      body: {'learner_id': learnerId, 'course': course},
    );
    return _writePartial(learnerId, data);
  }

  Future<LearnerStateModel> submitProgress({
    required String learnerId,
    int? xp,
    String? activityType,
    int? videoIndex,
    int? quizIndex,
    int? submissionIndex,
    String? fields,
  }) async {
    final data = await _http.post(
      ApiEndpoints.learnerSubmitProgress,
      body: {
        'learner_id': learnerId,
        'xp': ?xp,
        'activity_type': ?activityType,
        'video_index': ?videoIndex,
        'quiz_index': ?quizIndex,
        'submission_index': ?submissionIndex,
        'fields': ?fields,
      },
    );

    final mergedProgress = {
      ...data,
      'video_index': ?videoIndex,
      'quiz_index': ?quizIndex,
      'submission_index': ?submissionIndex,
    };

    final conflict = data['conflict'] == true;
    final recorded = data['progress_recorded'] == true;

    if (conflict && !recorded) {
      await _markConflict(learnerId);
      throw ProgressConflictException(data);
    }
    if (data['success'] == false) {
      throw ProgressNotRecordedException(data);
    }

    return _writeProgressResult(learnerId, mergedProgress);
  }

  Future<LearnerStateModel> applyLocalProgress({
    required String learnerId,
    int? videoIndex,
    int? quizIndex,
    int? submissionIndex,
  }) {
    return _writeProgressResult(learnerId, {
      'video_index': ?videoIndex,
      'quiz_index': ?quizIndex,
      'submission_index': ?submissionIndex,
    });
  }

  Future<void> applyAchievementAward(
    String learnerId,
    String achievement,
    String level,
  ) async {
    final existing = await readCached(learnerId);
    if (existing == null) return;
    existing.upsertAchievement(achievement, level);
    await _localCache.setForeverRaw(
      CacheKeys.learnerState(learnerId),
      existing.toJson(),
    );
  }

  Future<void> _markConflict(String learnerId) async {
    final existing = await readCached(learnerId);
    if (existing == null) return;
    existing.hasPendingConflict = true;
    await _localCache.setForeverRaw(
      CacheKeys.learnerState(learnerId),
      existing.toJson(),
    );
  }

  Future<LearnerStateModel> _writeFull(
    String learnerId,
    Map<String, dynamic> json, {
    bool clearConflict = false,
  }) async {
    final model = LearnerStateModel.fromFullJson(learnerId, json);
    if (clearConflict) model.hasPendingConflict = false;
    await _localCache.setForeverRaw(
      CacheKeys.learnerState(learnerId),
      model.toJson(),
    );
    return model;
  }

  Future<LearnerStateModel> _writePartial(
    String learnerId,
    Map<String, dynamic> json,
  ) async {
    final existing = await readCached(learnerId);
    final model = existing == null
        ? LearnerStateModel.fromFullJson(learnerId, json)
        : existing.mergeFrom(json);
    await _localCache.setForeverRaw(
      CacheKeys.learnerState(learnerId),
      model.toJson(),
    );
    return model;
  }

  Future<LearnerStateModel> _writeProgressResult(
    String learnerId,
    Map<String, dynamic> json,
  ) async {
    final model = await _writePartial(learnerId, json);
    model.hasPendingConflict = false;
    await _localCache.setForeverRaw(
      CacheKeys.learnerState(learnerId),
      model.toJson(),
    );
    return model;
  }

  Future<void> invalidate(String learnerId) =>
      _localCache.invalidateLearner(learnerId);
}

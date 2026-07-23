
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

    final data = await _http.get(ApiEndpoints.learnerState, query: {
      'learner_id': learnerId,
    });

    return _writeFull(learnerId, data);
  }

  Future<LearnerStateModel> enrollCourse({required String learnerId, required String course}) async {
    final data = await _http.post(ApiEndpoints.learnerEnroll, body: {
      'learner_id': learnerId,
      'course': course,
    });
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
    final data = await _http.post(ApiEndpoints.learnerSubmitProgress, body: {
      'learner_id': learnerId,
      if (xp != null) 'xp': xp,
      if (activityType != null) 'activity_type': activityType,
      if (videoIndex != null) 'video_index': videoIndex,
      if (quizIndex != null) 'quiz_index': quizIndex,
      if (submissionIndex != null) 'submission_index': submissionIndex,
      if (fields != null) 'fields': fields,
    });

    final conflict = data['conflict'] == true;
    final recorded = data['progress_recorded'] == true;

    if (conflict && !recorded) {
      await _markConflict(learnerId);
      throw ProgressConflictException(data);
    }

    return _writeFull(learnerId, data, clearConflict: true);
  }

  Future<void> applyAchievementAward(String learnerId, String achievement, String level) async {
    final existing = await readCached(learnerId);
    if (existing == null) return;
    existing.upsertAchievement(achievement, level);
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), existing.toJson());
  }

  Future<void> _markConflict(String learnerId) async {
    final existing = await readCached(learnerId);
    if (existing == null) return;
    existing.hasPendingConflict = true;
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), existing.toJson());
  }

  Future<LearnerStateModel> _writeFull(
    String learnerId,
    Map<String, dynamic> json, {
    bool clearConflict = false,
  }) async {
    final model = LearnerStateModel.fromFullJson(learnerId, json);
    if (clearConflict) model.hasPendingConflict = false;
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), model.toJson());
    return model;
  }

  Future<LearnerStateModel> _writePartial(String learnerId, Map<String, dynamic> json) async {
    final existing = await readCached(learnerId);
    final model = existing == null
        ? LearnerStateModel.fromFullJson(learnerId, json)
        : existing.mergeFrom(json);
    await _localCache.setForeverRaw(CacheKeys.learnerState(learnerId), model.toJson());
    return model;
  }

  Future<void> invalidate(String learnerId) => _localCache.invalidateLearner(learnerId);
}


import '../../core/cache/cache_keys.dart';
import '../../core/cache/local_cache.dart';
import '../models/achievement_model.dart';
import '../remote/api_endpoints.dart';
import '../remote/http_client.dart';
import 'learner_state_repository.dart';

class AchievementsRepository {
  AchievementsRepository(this._http, this._localCache, this._learnerStateRepository);

  final HttpClient _http;
  final LocalCache _localCache;
  final LearnerStateRepository _learnerStateRepository;

  Future<List<AchievementModel>> fetchAchievements(String learnerId, {bool forceRefresh = false}) async {
    final key = CacheKeys.achievements(learnerId);
    if (!forceRefresh && _localCache.has(key)) {
      final cached = _localCache.getForeverList(key, (json) => json);
      if (cached != null) return AchievementModel.listFromJson(cached);
    }

    final data = await _http.get(ApiEndpoints.achievements, query: {'learner_id': learnerId});
    final list = AchievementModel.listFromJson(data['achievements']);
    await _localCache.setForeverRawList(key, AchievementModel.listToJson(list));
    return list;
  }

  Future<Map<String, dynamic>> awardAchievement({
    required String learnerId,
    required String achievement,
    required int level,
  }) async {
    final data = await _http.post(ApiEndpoints.achievementsAward, body: {
      'learner_id': learnerId,
      'achievement': achievement,
      'level': level,
    });

    if (data['awarded'] == true) {
      final resultLevel = data['level']?.toString() ?? level.toString();
      await _learnerStateRepository.applyAchievementAward(learnerId, achievement, resultLevel);
      await _patchAchievementCache(learnerId, achievement, resultLevel);
    }
    return data;
  }

  Future<void> _patchAchievementCache(String learnerId, String achievement, String level) async {
    final key = CacheKeys.achievements(learnerId);
    final cachedRaw = _localCache.getForeverList(key, (json) => json);
    final list = cachedRaw == null ? <AchievementModel>[] : AchievementModel.listFromJson(cachedRaw);
    final idx = list.indexWhere((a) => a.achievement == achievement);
    final entry = AchievementModel(achievement: achievement, level: level);
    if (idx >= 0) {
      list[idx] = entry;
    } else {
      list.add(entry);
    }
    await _localCache.setForeverRawList(key, AchievementModel.listToJson(list));
  }
}

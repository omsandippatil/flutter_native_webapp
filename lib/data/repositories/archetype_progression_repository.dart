import '../../core/cache/cache_keys.dart';
import '../../core/cache/local_cache.dart';
import '../../models/learner_archetype.dart';
import '../../models/learner_state_model.dart';

class ArchetypeProgressionRepository {
  ArchetypeProgressionRepository(this._localCache);

  final LocalCache _localCache;

  Future<String> bumpAfterAcceptedSubmission(String learnerId) async {
    final key = CacheKeys.learnerState(learnerId);
    final raw = _localCache.getForeverRaw(key);
    if (raw == null) return LearnerArchetype.dormant;

    final model = LearnerStateModel.fromCache(raw);
    final bumped = LearnerArchetype.next(model.archetype);
    model.archetype = bumped;
    await _localCache.setForeverRaw(key, model.toJson());
    return bumped;
  }
}

import '../../core/cache/cache_keys.dart';
import '../../core/cache/local_cache.dart';
import '../../models/learner_archetype.dart';
import '../../models/learner_state_model.dart';

/// Every accepted submission bumps the learner one level up the archetype
/// ladder (dormant -> fence_sitter -> irregular_submitter -> submitter),
/// capping at submitter. This is applied optimistically on the client right
/// after a submission is accepted, then reconciled with whatever the server
/// returns on the next authoritative state fetch (server value always wins
/// if present).
class ArchetypeProgressionRepository {
  ArchetypeProgressionRepository(this._localCache);

  final LocalCache _localCache;

  /// Bumps [learnerId]'s cached archetype one level and returns the new
  /// value. Does not talk to the network — callers should still send the
  /// authoritative submission event to the server; this only keeps the
  /// local UI in sync until the next state refresh confirms it.
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
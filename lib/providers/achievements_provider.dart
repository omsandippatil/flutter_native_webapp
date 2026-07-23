import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement_model.dart';
import '../data/repositories/achievements_repository.dart';
import 'http_client_provider.dart';
import 'learner_state_provider.dart';
import 'local_cache_provider.dart';

final achievementsRepositoryProvider = FutureProvider<AchievementsRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  final learnerStateRepository = await ref.watch(learnerStateRepositoryProvider.future);
  return AchievementsRepository(ref.watch(httpClientProvider), localCache, learnerStateRepository);
});

final achievementsDataProvider = FutureProvider.autoDispose.family<List<AchievementModel>, String>(
  (ref, learnerId) async {
    final repository = await ref.watch(achievementsRepositoryProvider.future);
    return repository.fetchAchievements(learnerId);
  },
);

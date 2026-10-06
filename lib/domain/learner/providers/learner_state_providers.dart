import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/domain/learner/models/learner_state.dart';
import 'package:tapapp/domain/learner/data/learner_state_repository.dart';
import 'package:tapapp/providers/http_client_provider.dart';
import 'package:tapapp/providers/local_cache_provider.dart';

final learnerStateRepositoryProvider = FutureProvider<LearnerStateRepository>((
  ref,
) async {
  final localCache = await ref.watch(localCacheProvider.future);
  return LearnerStateRepository(ref.watch(httpClientProvider), localCache);
});

final learnerStateDataProvider = FutureProvider.autoDispose
    .family<LearnerStateModel, String>((ref, learnerId) async {
      final repository = await ref.watch(learnerStateRepositoryProvider.future);
      final cached = await repository.readCached(learnerId);
      if (cached != null && cached.enrollment != null) {
        return repository.restoreLocalProgress(cached);
      }
      return repository.fetchState(
        learnerId: learnerId,
        forceRefresh: cached != null,
      );
    });

Future<LearnerStateModel> refreshLearnerState(
  WidgetRef ref,
  String learnerId,
) async {
  final repository = await ref.read(learnerStateRepositoryProvider.future);
  return repository.fetchState(learnerId: learnerId, forceRefresh: true);
}

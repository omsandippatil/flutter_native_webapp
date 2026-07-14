import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/profile_summary_model.dart';
import '../data/repositories/roster_repository.dart';
import 'http_client_provider.dart';
import 'learner_state_provider.dart';
import 'local_cache_provider.dart';

final rosterRepositoryProvider = FutureProvider<RosterRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  final learnerStateRepository = await ref.watch(learnerStateRepositoryProvider.future);
  return RosterRepository(ref.watch(httpClientProvider), localCache, learnerStateRepository);
});

class RosterQuery {
  const RosterQuery({required this.phone, this.grade, this.division, this.query});
  final String phone;
  final String? grade;
  final String? division;
  final String? query;

  @override
  bool operator ==(Object other) =>
      other is RosterQuery &&
      other.phone == phone &&
      other.grade == grade &&
      other.division == division &&
      other.query == query;

  @override
  int get hashCode => Object.hash(phone, grade, division, query);
}

final rosterDataProvider = FutureProvider.autoDispose.family<List<ProfileSummaryModel>, RosterQuery>(
  (ref, query) async {
    final repository = await ref.watch(rosterRepositoryProvider.future);
    final cached = await repository.readCachedRoster(
      query.phone,
      grade: query.grade,
      division: query.division,
      query: query.query,
    );
    if (cached.isNotEmpty) return cached;
    return repository.fetchStudents(phone: query.phone, grade: query.grade, division: query.division);
  },
);

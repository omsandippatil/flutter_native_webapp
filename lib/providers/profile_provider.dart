import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/active_profile_model.dart';
import '../data/models/learner_state_model.dart';
import '../data/models/profile_summary_model.dart';
import '../data/repositories/profile_repository.dart';
import 'http_client_provider.dart';
import 'learner_state_provider.dart';
import 'local_cache_provider.dart';

final profileRepositoryProvider = FutureProvider<ProfileRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  final learnerStateRepository = await ref.watch(learnerStateRepositoryProvider.future);
  return ProfileRepository(ref.watch(httpClientProvider), localCache, learnerStateRepository);
});

class ProfilesPageRequest {
  const ProfilesPageRequest({required this.phone, this.page = 1, this.pageSize = 10});
  final String phone;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is ProfilesPageRequest && other.phone == phone && other.page == page && other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(phone, page, pageSize);
}

final profilesPageDataProvider =
    FutureProvider.autoDispose.family<List<ProfileSummaryModel>, ProfilesPageRequest>((ref, request) async {
  final repository = await ref.watch(profileRepositoryProvider.future);
  final cached = await repository.readCachedProfilesPage(request.phone, request.page, request.pageSize);
  if (cached.isNotEmpty) return cached;
  return repository.fetchProfilesPage(phone: request.phone, page: request.page, pageSize: request.pageSize);
});

final selectProfileProvider =
    FutureProvider.autoDispose.family<LearnerStateModel, ({String phone, String learnerId})>((ref, args) async {
  final repository = await ref.watch(profileRepositoryProvider.future);
  return repository.selectProfile(phone: args.phone, learnerId: args.learnerId);
});

/// The profile the user picked on the profile-select screen. Persisted forever
/// so the app can jump straight to Home on next launch without re-selecting.
final activeProfileProvider = FutureProvider<ActiveProfileModel?>((ref) async {
  final repository = await ref.watch(profileRepositoryProvider.future);
  return repository.readActiveProfile();
});

Future<void> setActiveProfile(WidgetRef ref, ActiveProfileModel profile) async {
  final repository = await ref.read(profileRepositoryProvider.future);
  await repository.setActiveProfile(profile);
  ref.invalidate(activeProfileProvider);
}

Future<void> clearActiveProfile(WidgetRef ref) async {
  final repository = await ref.read(profileRepositoryProvider.future);
  await repository.clearActiveProfile();
  ref.invalidate(activeProfileProvider);
}
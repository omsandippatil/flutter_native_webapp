import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/state_model.dart';
import '../data/repositories/onboarding_data_repository.dart';
import 'flow_repository_provider.dart';
import 'local_cache_provider.dart';

final onboardingDataRepositoryProvider = FutureProvider<OnboardingDataRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  final assetLoader = ref.watch(assetLoaderProvider);
  return OnboardingDataRepository(assetLoader, localCache);
});

final onboardingStatesProvider =
    FutureProvider.autoDispose.family<List<StateModel>, String>((ref, learnerId) async {
  final repository = await ref.watch(onboardingDataRepositoryProvider.future);
  return repository.loadStates(learnerId: learnerId);
});

class OnboardingDistrictsRequest {
  const OnboardingDistrictsRequest({required this.learnerId, required this.stateId});
  final String learnerId;
  final String stateId;

  @override
  bool operator ==(Object other) =>
      other is OnboardingDistrictsRequest &&
      other.learnerId == learnerId &&
      other.stateId == stateId;

  @override
  int get hashCode => Object.hash(learnerId, stateId);
}

final onboardingDistrictsProvider = FutureProvider.autoDispose
    .family<List<DistrictModel>, OnboardingDistrictsRequest>((ref, request) async {
  final repository = await ref.watch(onboardingDataRepositoryProvider.future);
  return repository.loadDistricts(learnerId: request.learnerId, stateId: request.stateId);
});

final onboardingConstantsProvider =
    FutureProvider.autoDispose.family<OnboardingConstantsModel, String>((ref, learnerId) async {
  final repository = await ref.watch(onboardingDataRepositoryProvider.future);
  return repository.loadConstants(learnerId: learnerId);
});

final onboardingLanguagesProvider =
    FutureProvider.autoDispose.family<List<OnboardingLanguageModel>, String>((ref, learnerId) async {
  final repository = await ref.watch(onboardingDataRepositoryProvider.future);
  return repository.loadLanguages(learnerId: learnerId);
});

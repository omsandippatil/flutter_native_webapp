import '../../core/cache/local_cache.dart';
import '../../core/cache/onboarding_cache_keys.dart';
import '../local/asset_loader.dart';
import '../../models/state_model.dart';

class OnboardingDataRepository {
  OnboardingDataRepository(this._assetLoader, this._localCache);

  final AssetLoader _assetLoader;
  final LocalCache _localCache;

  static const String _statesAssetPath = 'assets/data/constants/states.json';
  static const String _constantsAssetPath = 'assets/data/constants/constants.json';
  static const String _languagesAssetPath = 'assets/data/constants/languages.json';

  static String _districtAssetPath(String stateId) =>
      'assets/data/district/${StateModel.assetFileNameFor(stateId)}.json';

  Future<List<StateModel>> loadStates({
    required String learnerId,
    bool forceRefresh = false,
  }) async {
    final profileKey = OnboardingCacheKeys.profileStates(learnerId);
    if (!forceRefresh) {
      final cached = _localCache.getForeverList(profileKey, (json) => json);
      if (cached != null) return StateModel.listFromJson(cached);
    }

    final globalKey = OnboardingCacheKeys.statesIndex();
    var raw = _localCache.getForeverRaw(globalKey);
    List<dynamic> listRaw;
    if (raw != null && raw['states'] is List) {
      listRaw = raw['states'] as List;
    } else {
      final json = await _assetLoader.loadJsonAny(_statesAssetPath);
      listRaw = (json is List) ? json : ((json as Map)['states'] as List<dynamic>? ?? <dynamic>[]);
      await _localCache.setForeverRaw(globalKey, {'states': listRaw});
    }

    final states = StateModel.listFromJson(listRaw);
    await _localCache.setForeverRawList(profileKey, StateModel.listToJson(states));
    return states;
  }

  Future<List<DistrictModel>> loadDistricts({
    required String learnerId,
    required String stateId,
    bool forceRefresh = false,
  }) async {
    final profileKey = OnboardingCacheKeys.profileDistricts(learnerId, stateId);
    if (!forceRefresh) {
      final cached = _localCache.getForeverList(profileKey, (json) => json);
      if (cached != null) return DistrictModel.listFromJson(cached);
    }

    final globalKey = OnboardingCacheKeys.districtsForState(stateId);
    var raw = _localCache.getForeverRaw(globalKey);
    List<dynamic> listRaw;
    if (raw != null && raw['districts'] is List) {
      listRaw = raw['districts'] as List;
    } else {
      final json = await _assetLoader.loadJsonAny(_districtAssetPath(stateId));
      listRaw = (json is List) ? json : ((json as Map)['districts'] as List<dynamic>? ?? <dynamic>[]);
      await _localCache.setForeverRaw(globalKey, {'districts': listRaw});
    }

    final districts = DistrictModel.listFromJson(listRaw);
    await _localCache.setForeverRawList(profileKey, DistrictModel.listToJson(districts));
    return districts;
  }

  Future<OnboardingConstantsModel> loadConstants({
    required String learnerId,
    bool forceRefresh = false,
  }) async {
    final profileKey = OnboardingCacheKeys.profileConstants(learnerId);
    if (!forceRefresh) {
      final cached = _localCache.getForeverRaw(profileKey);
      if (cached != null) return OnboardingConstantsModel.fromJson(cached);
    }

    final globalKey = OnboardingCacheKeys.constants();
    var raw = _localCache.getForeverRaw(globalKey);
    raw ??= await _assetLoader.loadJson(_constantsAssetPath);
    await _localCache.setForeverRaw(globalKey, raw);

    final model = OnboardingConstantsModel.fromJson(raw);
    await _localCache.setForeverRaw(profileKey, model.toJson());
    return model;
  }

  Future<List<OnboardingLanguageModel>> loadLanguages({
    required String learnerId,
    bool forceRefresh = false,
  }) async {
    final profileKey = OnboardingCacheKeys.profileLanguages(learnerId);
    if (!forceRefresh) {
      final cached = _localCache.getForeverList(profileKey, (json) => json);
      if (cached != null) return OnboardingLanguageModel.listFromJson(cached);
    }

    final globalKey = OnboardingCacheKeys.languages();
    var raw = _localCache.getForeverRaw(globalKey);
    List<dynamic> listRaw;
    if (raw != null && raw['languages'] is List) {
      listRaw = raw['languages'] as List;
    } else {
      final json = await _assetLoader.loadJsonAny(_languagesAssetPath);
      listRaw = (json is List) ? json : ((json as Map)['languages'] as List<dynamic>? ?? <dynamic>[]);
      await _localCache.setForeverRaw(globalKey, {'languages': listRaw});
    }

    final languages = OnboardingLanguageModel.listFromJson(listRaw);
    await _localCache.setForeverRawList(profileKey, OnboardingLanguageModel.listToJson(languages));
    return languages;
  }

  Future<void> invalidateForProfile(String learnerId) async {
    await _localCache.deletePrefix('v2:onboarding:profile:$learnerId:');
  }

  Future<void> primeProfileCache({
    required String learnerId,
    String? stateId,
  }) async {
    await loadStates(learnerId: learnerId);
    await loadConstants(learnerId: learnerId);
    await loadLanguages(learnerId: learnerId);
    if (stateId != null) {
      await loadDistricts(learnerId: learnerId, stateId: stateId);
    }
  }
}

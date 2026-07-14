class OnboardingCacheKeys {
  OnboardingCacheKeys._();

  static const String schemaVersion = 'v2';

  static String _k(String parts) => '$schemaVersion:$parts';

  static String statesIndex() => _k('onboarding:states:index');

  static String districtsForState(String stateId) =>
      _k('onboarding:districts:$stateId');

  static String constants() => _k('onboarding:constants');

  static String languages() => _k('onboarding:languages');

  static String profileScoped(String learnerId, String suffix) =>
      _k('onboarding:profile:$learnerId:$suffix');

  static String profileStates(String learnerId) =>
      profileScoped(learnerId, 'states');

  static String profileDistricts(String learnerId, String stateId) =>
      profileScoped(learnerId, 'districts:$stateId');

  static String profileConstants(String learnerId) =>
      profileScoped(learnerId, 'constants');

  static String profileLanguages(String learnerId) =>
      profileScoped(learnerId, 'languages');

  static bool belongsToProfile(String key, String learnerId) =>
      key.contains(':profile:$learnerId:');
}

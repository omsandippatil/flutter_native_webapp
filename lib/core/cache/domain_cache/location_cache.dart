class LocationCache {
  LocationCache._();

  static const String schemaVersion = 'v2';

  static String _k(String parts) => '$schemaVersion:$parts';

  static String states() => _k('location:states');

  static String districts(String stateId) => _k('location:districts:$stateId');
}
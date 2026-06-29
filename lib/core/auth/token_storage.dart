// token_storage.dart
// Persists the JWT session token and the currently active profile ID.
// Provides read/write/clear methods used by auth_service.dart.
// On web: SharedPreferences. On native: flutter_secure_storage.
// Never stores OTP or plaintext passwords here.

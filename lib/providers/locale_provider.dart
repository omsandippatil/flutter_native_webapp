// locale_provider.dart
// Riverpod StateNotifier for the app locale.
// Supported: en, hi, mr, kn.
// Loads saved locale from SharedPreferences on init (defaults to device locale).
// setLocale(code): saves to SharedPreferences + updates the MaterialApp locale.
// Consumed by settings_screen.dart for the language selector UI.

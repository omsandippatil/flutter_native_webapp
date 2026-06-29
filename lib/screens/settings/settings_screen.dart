// settings_screen.dart
// Settings screen — intentionally minimal.
// Language selector: shows supported locales (English, Hindi, Marathi, Kannada).
//   Tap a language → locale_provider.setLocale(code) → app relocalises instantly.
// Logout button: calls auth_provider.logout → clears token + active profile
//   → navigates to /login and removes all back-stack history.
// Nothing else here for now.

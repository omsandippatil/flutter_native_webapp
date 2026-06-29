// router.dart
// GoRouter setup for the entire app.
// Named routes: splash, landing, login, otp, password, profile_select,
//               chat, passport, settings.
// Route guards:
//   - No token → redirect to /login
//   - Token but no active profile → redirect to /profile-select
//   - Token + active profile → /chat is the home base
// Chat screen handles all flow rendering; no separate quiz/activity routes needed.

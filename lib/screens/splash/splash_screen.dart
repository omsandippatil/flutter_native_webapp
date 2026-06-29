// splash_screen.dart
// First screen on launch. Shows app logo/branding.
// On init: reads token from token_storage.
//   No token → navigate to /landing or /login.
//   Token + no active profile → navigate to /profile-select.
//   Token + active profile → load progress, navigate to /chat.
// No user interaction — pure routing logic with a brief branded moment.

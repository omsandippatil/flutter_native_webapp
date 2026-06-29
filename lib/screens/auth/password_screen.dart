// password_screen.dart
// Dual-purpose password screen.
// New user mode: two fields (password + confirm), calls auth_provider.setPassword.
// Returning user mode: single field, calls auth_provider.loginWithPassword.
// Mode is passed as a route parameter from otp_screen.
// On success: navigate to /profile-select.
// Password rules: minimum length only — no complexity requirements for now.

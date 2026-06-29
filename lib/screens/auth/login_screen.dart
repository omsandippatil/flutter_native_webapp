// login_screen.dart
// Phone number entry screen — the start of the auth flow.
// Single input: phone number with country code prefix.
// On continue: calls auth_provider.requestOtp(phone).
// On success: router navigates to /otp.
// On error: shows inline error message (not a dialog).
// No sign-up / no email — phone-only entry.

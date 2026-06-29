// auth_service.dart
// Orchestrates the full authentication lifecycle.
// requestOtp(phone): calls worker /auth/otp to send OTP SMS.
// verifyOtp(phone, otp): verifies OTP, returns token + isNewUser flag.
// setPassword(password): called once for new users to set their password.
// loginWithPassword(phone, password): for returning users.
// logout(): clears token and active profile from token_storage.
// All network calls go through api_client.dart.

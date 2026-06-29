// otp_screen.dart
// OTP verification screen.
// Shows: "Enter the code sent to +91 XXXXXXXX" with the phone number.
// 6-digit input — auto-submits when all 6 digits are entered.
// On verify: calls auth_provider.verifyOtp(phone, otp).
//   isNewUser true → navigate to /password (set password).
//   isNewUser false → navigate to /password (enter existing password).
// Resend button appears after 30 seconds; calls auth_provider.requestOtp again.

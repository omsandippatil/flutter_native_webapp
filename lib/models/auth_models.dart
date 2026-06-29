// auth_models.dart
// Data models for the authentication flow.
// PhoneSession: holds phone number during OTP flow (not persisted).
// OtpRequest: request body sent to worker /auth/otp.
// PasswordSetup: body for first-time password creation endpoint.
// AuthToken: JWT + expiry returned by the worker. Persisted via Isar.

// auth.js
// Handles OTP send, OTP verify, password set/check, and token validation.
//
// sendOtp(phone, env):
//   Generates a 6-digit OTP, stores in KV as "otp:{phone}" with 300s TTL.
//   Calls the SMS provider API (key from env.SMS_API_KEY).
//
// verifyOtp(phone, otp, env):
//   Reads "otp:{phone}" from KV. Compares. Deletes on match.
//   Checks if account exists → sets isNewUser flag.
//   Returns signed JWT via jwt.js.
//
// setPassword(phone, password, env):
//   Hashes password with bcrypt (or SubtleCrypto PBKDF2 for Workers).
//   Upserts account row in D1.
//
// loginWithPassword(phone, password, env):
//   Fetches account from D1. Compares hash. Returns signed JWT.
//
// validateToken(request, env):
//   Extracts Bearer token. Verifies signature via jwt.js.
//   Checks jti against sessions table (blacklist). Returns phone claim.

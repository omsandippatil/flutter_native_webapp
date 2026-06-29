// routes.js
// Declares all API route handlers.
// Route table maps [METHOD, path pattern] to an async handler function.
// Authenticated routes run auth.js validateToken before the handler.
//
// Public routes (no token needed):
//   POST /auth/otp       → request OTP SMS for a phone number
//   POST /auth/verify    → verify OTP, return JWT + isNewUser flag
//   POST /auth/password  → set password (new user) or login (returning)
//
// Authenticated routes (JWT required):
//   POST /auth/logout        → revoke JWT (add jti to sessions table)
//   GET  /profiles           → list all profiles for the authed phone
//   GET  /progress/:profileId → fetch progress for a profile
//   POST /progress/:profileId → save/update progress for a profile
//
// All handlers receive: (request, env, ctx, params)

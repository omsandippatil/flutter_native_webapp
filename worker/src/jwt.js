// jwt.js
// JWT creation and verification using the Web Crypto API (no npm deps).
// Workers do not support Node crypto — uses SubtleCrypto exclusively.
//
// sign(payload, secret):
//   Creates a HS256 JWT. Payload includes: sub (phone), jti (uuid), iat, exp.
//   Returns the JWT string.
//
// verify(token, secret):
//   Verifies the HS256 signature. Checks exp claim.
//   Returns the decoded payload or throws on invalid/expired token.
//
// The secret comes from env.JWT_SECRET (set via: wrangler secret put JWT_SECRET).

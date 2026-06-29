// ratelimit.js
// IP-based rate limiting backed by Cloudflare KV.
//
// checkLimit(ip, route, env):
//   Reads counter from KV key "rl:{route}:{ip}".
//   OTP routes (/auth/otp): max 5 requests per hour.
//   All other routes: max 60 requests per minute.
//   Increments counter. Sets TTL on first write.
//   Returns { allowed: bool, remaining: int }.
//
// If not allowed: caller returns 429 Too Many Requests.
// KV TTL handles automatic counter reset — no cron needed.

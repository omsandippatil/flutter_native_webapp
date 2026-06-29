// api_client.dart
// The one HTTP client for all Cloudflare Worker API calls.
// Attaches the JWT Bearer token from token_storage to every request.
// On 401: attempts a token refresh then retries once before throwing.
// Exposes typed methods: sendOtp, verifyOtp, setPassword, fetchProfiles,
// saveProgress, fetchProgress.
// No other file in the app makes raw HTTP calls.

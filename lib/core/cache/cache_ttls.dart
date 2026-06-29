// cache_ttls.dart
// Defines the cache duration policy for each data category.
// Flows (course, activity, onboarding): cache forever — loaded once, never re-fetched.
// Audio files: cache forever — large assets, never re-download.
// Progress data: no TTL — always written through to backend on change.
// JWT token: not TTL'd here; expiry is read from the token claim itself.

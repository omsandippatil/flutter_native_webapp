// cache_service.dart
// The single cache access point for all services.
// Wraps Isar with typed helpers: getFlow, setFlow, getAudioBytes, setAudioBytes,
//   getProgress, setProgress, getProfiles, setProfiles.
// Lazy strategy: caller checks cache first; on miss, fetches then calls set.
// Flows and audio: stored forever (no expiry).
// Progress: written through on every update.
// Never access Isar directly from any service — always go through here.

// flow_resolver.dart
// Resolves a flow ID to its asset file path using the flow_manifest.json index.
// Loaded once at app startup and kept in memory.
// Usage: FlowResolver.pathFor("activity_001") → "assets/flows/activity/activity_001.json"
// Also resolves audio IDs: FlowResolver.audioFor("audio_greet_01") → "assets/audio/..."
// Throws if an ID is not found in the manifest — fail fast, fail loud.

// audio_service.dart
// Manages prerecorded audio playback for flow steps.
// play(audioId): resolves audio path via flow_resolver, checks Isar byte cache,
//   loads from assets if not cached, caches bytes, then plays.
// stop(): stops current playback.
// On web: plays via HTML <audio> element using dart:js_interop.
// On native: uses just_audio package.
// Audio bytes are cached forever in Isar — never re-read from bundle after first load.

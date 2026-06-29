// audio_provider.dart
// Riverpod StateNotifier for audio playback state.
// isPlaying: bool — reflects current playback state.
// play(audioId): delegates to audio_service; updates isPlaying.
// stop(): stops playback via audio_service; sets isPlaying false.
// Consumed by audio_player.dart widget and chat_bubble.dart for inline play buttons.

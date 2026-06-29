// chat_bubble.dart
// Renders one chat message bubble.
// Bot messages: left-aligned, bot avatar, app accent color background.
// User messages: right-aligned, neutral background.
// If the message has an audioId: shows a small play/pause button inline.
//   Tapping calls audio_provider.play(audioId).
// Does not handle quiz_card, option_picker, or video slots — those are
//   separate widget types rendered by chat_message_list based on message.type.

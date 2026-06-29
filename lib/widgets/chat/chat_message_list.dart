// chat_message_list.dart
// Scrollable list of all ChatMessages in the current session.
// Reads from chat_provider.messages.
// Renders each message using the correct widget based on message.type:
//   "text" or "audio" → chat_bubble.dart
//   "quiz_card"       → quiz_card.dart
//   "option_picker"   → option_picker.dart
//   "video_slot"      → video_slot.dart
//   "submission_card" → submission_card.dart
// Auto-scrolls to the bottom whenever a new message is appended.
// Shows typing_indicator.dart while the next bot step is loading.

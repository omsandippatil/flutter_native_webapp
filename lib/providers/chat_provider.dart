// chat_provider.dart
// Riverpod StateNotifier — the source of truth for what is visible in the chat UI.
// Holds: List<ChatMessage> displayed in chat_message_list.dart.
// addBotMessage(step): converts a FlowStep into a ChatMessage and appends it.
// addUserMessage(text): appends the user's reply as a ChatMessage.
// clearSession(): resets the list when starting a new flow.
// Does not contain flow logic — it only manages the visual message list.

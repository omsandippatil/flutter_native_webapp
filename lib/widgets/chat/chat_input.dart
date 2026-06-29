// chat_input.dart
// The chat input area fixed at the bottom of chat_screen.
// Shows a text field + send button when the current flow step expects text input.
// Hidden when the active step uses option_picker, quiz_card, or video_slot
//   (those widgets handle their own submission).
// On send: calls flow_provider.advance(userInput).
// Handles keyboard show/hide gracefully on web and mobile.

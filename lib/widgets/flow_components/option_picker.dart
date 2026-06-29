// option_picker.dart
// Renders a set of tappable option buttons inside the chat.
// Used for flow branching steps — user picks a path, not a quiz answer.
// Options appear as rounded pill buttons below the bot message.
// On tap: selected option is echoed as a user ChatMessage, then
//   flow_provider.advance(selectedOption) is called.
// After selection: buttons disappear and are replaced by the echoed user message.

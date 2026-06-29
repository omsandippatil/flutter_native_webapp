// chat_screen.dart
// The primary screen of the app — a chat interface that runs all flows.
// Renders: app_header (with profile switcher), chat_message_list, chat_input.
// On mount: checks progress_provider for current step, calls flow_provider.startFlow.
// chat_provider feeds the message list; flow_provider drives what comes next.
// Interactive slots (quiz, option_picker, video, submission) render as
//   special ChatMessage types inside the list — not as separate screens.
// Audio steps: auto-plays via audio_provider when message is added.
// User input at the bottom is context-aware: plain text, option buttons, or submit.

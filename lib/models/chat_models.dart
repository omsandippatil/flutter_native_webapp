// chat_models.dart
// Models for the live chat session rendered on chat_screen.dart.
// ChatMessage: one message bubble — sender (bot/user), content, type, timestamp.
// Message types: text, audio, quiz_card, option_picker, video_slot, submission_card.
// ChatSession: the live session state — active flow ID, step cursor, accumulated answers.
// Not persisted to Isar; rebuilt from progress on app resume.

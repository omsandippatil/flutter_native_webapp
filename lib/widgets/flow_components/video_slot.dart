// video_slot.dart
// Renders a video player inline inside the chat message list.
// The video URL/ID comes from the activity slot data resolved by activity_service.
// Uses video_player package (web + native compatible).
// On video end: auto-advances — calls activity_provider.submitSlot("video_complete").
// "Skip" / "Continue" button also available if video can be skipped.

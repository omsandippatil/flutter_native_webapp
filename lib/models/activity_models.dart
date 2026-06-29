// activity_models.dart
// Models for the activity template system.
// ActivityTemplate: the reusable shell JSON loaded once and shared.
// ActivitySlot: a typed placeholder — quiz, video, submission, message, audio.
// ActivityInstance: a template + a specific slot-filling from activity_manifest.json.
// LoopState: tracks how many attempts the student has made on the current activity.
// The activity_service.dart combines template + manifest entry to build an ActivityInstance.

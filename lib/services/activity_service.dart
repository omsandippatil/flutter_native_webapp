// activity_service.dart
// Manages activity execution within the chat flow.
// buildInstance(activityId): loads activity_template.json + looks up activityId
//   in activity_manifest.json, merges them into an ActivityInstance.
// runLoop(instance): steps through all slots in the activity; on completion
//   checks the loop_until condition; if not met, resets and repeats.
// Reports completion back to flow_service so the course flow can advance.
// All slot content (quiz, video, audio IDs) come from the manifest — not hardcoded.

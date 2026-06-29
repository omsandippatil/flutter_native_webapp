// activity_provider.dart
// Riverpod StateNotifier — manages a single running activity.
// startActivity(activityId): builds ActivityInstance via activity_service.
// currentSlot: the slot currently being rendered in chat (quiz, video, audio, etc).
// submitSlot(answer): records the answer and advances to the next slot.
// When all slots done: evaluates loop_until condition.
//   If condition met → marks complete, notifies flow_provider.
//   If not met → resets to first slot and repeats (the loop).

// progress_provider.dart
// Riverpod StateNotifier for the active profile's course progress.
// Loaded from Isar on profile select, reconciled with backend in background.
// currentStepIndex: where in course_flow.json the student currently is.
// completedActivityIds: set of finished activity IDs.
// markStepComplete(index): updates local state + calls progress_service to save.
// Used by flow_provider to know where to resume the course flow.

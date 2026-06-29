// progress_models.dart
// Tracks one student profile's progress through their course.
// Fields: profileId, courseFlowId, currentStepIndex, completedActivityIds, lastActiveAt.
// Written to Isar on every step completion (write-through, no TTL).
// Also synced to the backend so progress survives reinstalls.
// Keyed by profileId — each child has a fully independent progress record.

// progress_service.dart
// Manages per-profile progress through the course flow.
// saveStep(profileId, stepIndex): writes to Isar + calls api_client to sync backend.
// markActivityComplete(profileId, activityId): adds to completedActivityIds.
// loadProgress(profileId): reads from Isar first; if missing, fetches from backend.
// Progress is keyed by profileId so each child's data is fully independent.
// Write-through on every update — progress loss on crash is unacceptable.

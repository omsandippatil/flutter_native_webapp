// profile_service.dart
// Manages the list of student profiles under a phone account.
// fetchProfiles(): hits the worker, caches result in Isar, returns list.
// getCachedProfiles(): returns from Isar without a network call.
// setActiveProfile(profileId): writes to token_storage — used on profile select screen.
// getActiveProfile(): reads currently active profile from cache.
// Supports multiple children under one phone login with independent progress.

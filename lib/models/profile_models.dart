// profile_models.dart
// Represents one student profile under a phone number account.
// Fields: profileId, displayName, avatarIndex, courseId, createdAt.
// Multiple profiles share one phone login — each has independent progress.
// Isar schema: persisted locally, synced from backend on login.
// The active profile ID is held in token_storage.dart at runtime.

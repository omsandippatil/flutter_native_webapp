// profile_provider.dart
// Riverpod StateNotifier for student profile management.
// Holds: list of profiles fetched from backend, currently active profile.
// loadProfiles(): fetches via profile_service, caches in Isar.
// setActiveProfile(profileId): updates active profile, triggers progress load.
// Used by profile_select_screen and profile_switcher widget.

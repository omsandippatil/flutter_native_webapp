// profile_switcher.dart
// A dropdown or bottom sheet widget for switching the active student profile.
// Triggered from the app header (avatar tap or name tap).
// Lists all profiles from profile_provider.profiles.
// Tap a different profile → profile_provider.setActiveProfile(id)
//   → progress_provider reloads for new profile → chat_provider clears + resumes flow.
// Does not navigate away from chat_screen — the switch happens in place.

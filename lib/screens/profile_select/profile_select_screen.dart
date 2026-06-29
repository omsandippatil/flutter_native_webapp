// profile_select_screen.dart
// Shown after login and when switching between child profiles.
// Displays a card grid of all student profiles under the phone account.
// Tap a profile → profile_provider.setActiveProfile(id) → navigate to /chat.
// "Add student" card → (future: create profile flow).
// Profiles are loaded from Isar cache first; background sync with backend.
// This screen is also navigated to from the profile_switcher widget in the header.

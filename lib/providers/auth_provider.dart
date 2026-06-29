// auth_provider.dart
// Riverpod StateNotifier for authentication state.
// States: unauthenticated → otpSent → otpVerified → passwordRequired → authenticated.
// Methods: requestOtp, verifyOtp, setPassword, loginWithPassword, logout.
// Delegates to auth_service.dart for all logic.
// On authenticated: triggers profile_provider to fetch profiles.

#!/bin/bash

# =============================================================================
# SETUP SCRIPT — Conversational Learning App
# Flutter web app + Cloudflare Worker backend
#
# Run this from the root of your project directory:
#   chmod +x setup.sh && ./setup.sh
#
# What this does:
#   1. Creates the Flutter app structure (lib/, assets/, l10n/)
#   2. Creates the Cloudflare Worker structure (worker/)
#   3. Writes a descriptive comment into every file explaining its role
#   4. Does NOT write any implementation code — that is your job
# =============================================================================

set -e

echo "=> Creating Flutter app scaffold..."

# =============================================================================
# FLUTTER — CORE
# =============================================================================

mkdir -p lib/core/auth
mkdir -p lib/core/cache
mkdir -p lib/core/router
mkdir -p lib/core/theme
mkdir -p lib/core/utils

# Persists the auth session token and active profile ID to local storage.
# On web uses SharedPreferences, on app uses secure_storage.
# Never stores OTP or plaintext password — only the JWT returned post-auth.
cat > lib/core/auth/token_storage.dart << 'EOF'
// token_storage.dart
// Persists the JWT session token and the currently active profile ID.
// Provides read/write/clear methods used by auth_service.dart.
// On web: SharedPreferences. On native: flutter_secure_storage.
// Never stores OTP or plaintext passwords here.
EOF

# Keys used across the entire cache layer — one place to define them.
# All Isar collection names and cache key prefixes live here.
# Import this wherever you call cache_store.dart.
cat > lib/core/cache/cache_keys.dart << 'EOF'
// cache_keys.dart
// Single source of truth for every key used in the Isar cache.
// Defines string constants for: flow cache, audio cache, progress cache,
// profile cache, and course state cache.
// Import here instead of writing key strings inline elsewhere.
EOF

# The unified Isar-backed cache store.
# All reads and writes to persistent cache go through here.
# Works on web (IndexedDB via Isar web) and native (Isar file DB).
# Exposes get / set / delete / clear per collection.
cat > lib/core/cache/cache_store.dart << 'EOF'
// cache_store.dart
// Isar-backed cache that works on both Flutter web and native apps.
// Exposes generic get/set/delete/clear methods used by all services.
// Isar web uses IndexedDB under the hood — same API, same code.
// All cached data is stored with a key string and a JSON-serialised value.
// Cache is lazy: data is written on first fetch and never re-fetched
// unless explicitly invalidated. See cache_ttls.dart for expiry rules.
EOF

# TTL and invalidation policy for each type of cached data.
# Flows and audio: cache forever (never expire unless user clears data).
# Progress: no TTL, always write-through on every update.
# Auth token: expires per JWT claim, checked on app resume.
cat > lib/core/cache/cache_ttls.dart << 'EOF'
// cache_ttls.dart
// Defines the cache duration policy for each data category.
// Flows (course, activity, onboarding): cache forever — loaded once, never re-fetched.
// Audio files: cache forever — large assets, never re-download.
// Progress data: no TTL — always written through to backend on change.
// JWT token: not TTL'd here; expiry is read from the token claim itself.
EOF

# The GoRouter configuration for the entire app.
# Defines all named routes and their screen mappings.
# Guards: unauthenticated users → login, authenticated with no profile selected → profile_select.
# The chat screen is the default destination after profile selection.
cat > lib/core/router/router.dart << 'EOF'
// router.dart
// GoRouter setup for the entire app.
// Named routes: splash, landing, login, otp, password, profile_select,
//               chat, passport, settings.
// Route guards:
//   - No token → redirect to /login
//   - Token but no active profile → redirect to /profile-select
//   - Token + active profile → /chat is the home base
// Chat screen handles all flow rendering; no separate quiz/activity routes needed.
EOF

# App-wide ThemeData — colors, typography, button styles, input decoration.
# Built to match a conversational / chat-first UI aesthetic.
# Defines light theme only for now (dark theme can be added later).
cat > lib/core/theme/app_theme.dart << 'EOF'
// app_theme.dart
// ThemeData for the entire app.
// Sets color scheme, text styles, button themes, input decoration,
// and chat bubble colors.
// All screens consume theme via Theme.of(context) — no hardcoded colors elsewhere.
EOF

# App-wide string constants: API base URL, asset path prefixes, default locale.
# Never put secrets here — those go in environment config or the worker.
cat > lib/core/utils/constants.dart << 'EOF'
// constants.dart
// App-wide constants: API base URL, asset path prefixes for flows and audio,
// default locale code, max OTP retry count, and app version string.
// No secrets here — worker handles auth secrets server-side.
EOF

# Miscellaneous pure utility functions used across the app.
# Date formatting, string sanitisation, locale helpers.
# No Flutter widget imports here — pure Dart only.
cat > lib/core/utils/helpers.dart << 'EOF'
// helpers.dart
// Stateless pure utility functions used across the app.
// Includes: format duration, sanitise phone number, strip country code,
// truncate string, and check if a string is a valid flow ID format.
// No Flutter imports — pure Dart only so it can be tested easily.
EOF

# Given a flow ID string, resolves it to the correct asset path.
# Reads the flow_manifest.json at startup and builds an in-memory lookup map.
# All services use this instead of hard-coding asset paths.
cat > lib/core/utils/flow_resolver.dart << 'EOF'
// flow_resolver.dart
// Resolves a flow ID to its asset file path using the flow_manifest.json index.
// Loaded once at app startup and kept in memory.
// Usage: FlowResolver.pathFor("activity_001") → "assets/flows/activity/activity_001.json"
// Also resolves audio IDs: FlowResolver.audioFor("audio_greet_01") → "assets/audio/..."
// Throws if an ID is not found in the manifest — fail fast, fail loud.
EOF

# =============================================================================
# FLUTTER — MODELS
# =============================================================================

mkdir -p lib/models

# Auth-related data models: PhoneSession, OtpRequest, PasswordSetup, AuthToken.
# These are plain Dart classes with fromJson/toJson.
# Isar schema annotations added only to AuthToken (it is persisted in cache).
cat > lib/models/auth_models.dart << 'EOF'
// auth_models.dart
// Data models for the authentication flow.
// PhoneSession: holds phone number during OTP flow (not persisted).
// OtpRequest: request body sent to worker /auth/otp.
// PasswordSetup: body for first-time password creation endpoint.
// AuthToken: JWT + expiry returned by the worker. Persisted via Isar.
EOF

# Student profile model: one per child under a phone account.
# Stored in Isar so profile list is available offline.
# Contains display name, avatar choice, and a unique profile ID.
# Progress is stored separately keyed by this profile ID.
cat > lib/models/profile_models.dart << 'EOF'
// profile_models.dart
// Represents one student profile under a phone number account.
// Fields: profileId, displayName, avatarIndex, courseId, createdAt.
// Multiple profiles share one phone login — each has independent progress.
// Isar schema: persisted locally, synced from backend on login.
// The active profile ID is held in token_storage.dart at runtime.
EOF

# Models for the flow engine: FlowStep, FlowMessage, FlowAction, AudioSlot.
# These map directly to the shape of JSON in assets/flows/.
# The flow engine in flow_service.dart deserialises these from JSON.
cat > lib/models/flow_models.dart << 'EOF'
// flow_models.dart
// Dart representations of the flow JSON schema.
// FlowStep: one step in a flow — has a type (message, action, branch, activity).
// FlowMessage: a bot message with optional audioId and text content.
// FlowAction: a user-facing action (tap option, input text, proceed).
// FlowBranch: conditional next-step logic based on prior user input.
// AudioSlot: references a prerecorded audio asset by ID.
// All classes have fromJson constructors — no code generation needed.
EOF

# Chat session and message models used by the chat UI layer.
# ChatMessage is what gets rendered in the message list.
# ChatSession holds the live session state: current flow ID, step index.
cat > lib/models/chat_models.dart << 'EOF'
// chat_models.dart
// Models for the live chat session rendered on chat_screen.dart.
// ChatMessage: one message bubble — sender (bot/user), content, type, timestamp.
// Message types: text, audio, quiz_card, option_picker, video_slot, submission_card.
// ChatSession: the live session state — active flow ID, step cursor, accumulated answers.
// Not persisted to Isar; rebuilt from progress on app resume.
EOF

# Activity template model: the reusable shell that every activity runs through.
# Slots are typed placeholders — quiz, video, submission, message, audio.
# The activity_service fills these slots with real content from the activity manifest.
cat > lib/models/activity_models.dart << 'EOF'
// activity_models.dart
// Models for the activity template system.
// ActivityTemplate: the reusable shell JSON loaded once and shared.
// ActivitySlot: a typed placeholder — quiz, video, submission, message, audio.
// ActivityInstance: a template + a specific slot-filling from activity_manifest.json.
// LoopState: tracks how many attempts the student has made on the current activity.
// The activity_service.dart combines template + manifest entry to build an ActivityInstance.
EOF

# Per-profile progress: which course step the student is on, completed activity IDs.
# Written through to backend on every update and cached locally in Isar.
# Keyed by profileId so multiple kids under one phone stay independent.
cat > lib/models/progress_models.dart << 'EOF'
// progress_models.dart
// Tracks one student profile's progress through their course.
// Fields: profileId, courseFlowId, currentStepIndex, completedActivityIds, lastActiveAt.
// Written to Isar on every step completion (write-through, no TTL).
// Also synced to the backend so progress survives reinstalls.
// Keyed by profileId — each child has a fully independent progress record.
EOF

# =============================================================================
# FLUTTER — DATA LAYER
# =============================================================================

mkdir -p lib/data/local
mkdir -p lib/data/remote

# Loads raw JSON and audio assets from the Flutter asset bundle.
# Used by flow_service and audio_service to read files from assets/.
# Returns raw string for JSON, ByteData for audio.
cat > lib/data/local/asset_loader.dart << 'EOF'
// asset_loader.dart
// Reads files from the Flutter asset bundle at runtime.
// loadJson(path): returns the decoded JSON map for a given asset path.
// loadAudioBytes(path): returns ByteData for an audio asset (for caching).
// All paths come from flow_resolver.dart — never hard-coded here.
// Wraps rootBundle.loadString and rootBundle.load with error handling.
EOF

# Loads and holds the flow manifest in memory.
# The manifest (flow_manifest.json) maps every flow ID to its asset path.
# Initialised once at app startup by the flow_provider.
cat > lib/data/local/flow_index.dart << 'EOF'
// flow_index.dart
// Loads assets/flows/flow_manifest.json and builds an in-memory ID → path map.
// Initialised once by flow_provider at startup.
// Provides: pathForFlowId(id), pathForAudioId(id), allFlowIds().
// If a requested ID is absent from the manifest, throws a descriptive error.
EOF

# Single HTTP client for all calls to the Cloudflare Worker backend.
# Handles JWT attachment, error parsing, and retry on 401 (token refresh).
# All methods return typed model objects — no raw HTTP elsewhere in the app.
cat > lib/data/remote/api_client.dart << 'EOF'
// api_client.dart
// The one HTTP client for all Cloudflare Worker API calls.
// Attaches the JWT Bearer token from token_storage to every request.
// On 401: attempts a token refresh then retries once before throwing.
// Exposes typed methods: sendOtp, verifyOtp, setPassword, fetchProfiles,
// saveProgress, fetchProgress.
// No other file in the app makes raw HTTP calls.
EOF

# =============================================================================
# FLUTTER — SERVICES
# =============================================================================

mkdir -p lib/services

# Handles OTP request, OTP verification, first-time password setup,
# returning-user password login, and logout.
# Calls api_client.dart for all network operations.
# Writes the returned JWT to token_storage on success.
cat > lib/services/auth_service.dart << 'EOF'
// auth_service.dart
// Orchestrates the full authentication lifecycle.
// requestOtp(phone): calls worker /auth/otp to send OTP SMS.
// verifyOtp(phone, otp): verifies OTP, returns token + isNewUser flag.
// setPassword(password): called once for new users to set their password.
// loginWithPassword(phone, password): for returning users.
// logout(): clears token and active profile from token_storage.
// All network calls go through api_client.dart.
EOF

# Fetches the list of student profiles for the logged-in phone number.
# Caches profiles in Isar so the profile select screen works offline.
# Exposes setActiveProfile which writes the profile ID to token_storage.
cat > lib/services/profile_service.dart << 'EOF'
// profile_service.dart
// Manages the list of student profiles under a phone account.
// fetchProfiles(): hits the worker, caches result in Isar, returns list.
// getCachedProfiles(): returns from Isar without a network call.
// setActiveProfile(profileId): writes to token_storage — used on profile select screen.
// getActiveProfile(): reads currently active profile from cache.
// Supports multiple children under one phone login with independent progress.
EOF

# The flow engine. Loads a flow JSON by ID (from cache or assets),
# parses it into FlowStep models, and exposes a step cursor.
# Called by flow_provider; the provider feeds steps to chat_provider.
cat > lib/services/flow_service.dart << 'EOF'
// flow_service.dart
// The core flow engine — loads, parses, and steps through any flow by ID.
// loadFlow(flowId): checks Isar cache first, falls back to asset_loader, then caches forever.
// currentStep: the FlowStep at the current cursor position.
// advance(): moves cursor forward, handles branching by evaluating FlowBranch conditions.
// When a step has type "activity", delegates to activity_service.dart.
// When a step has type "audio", triggers audio_service.dart.
// Flow state (cursor position) lives in flow_provider — not in this service.
EOF

# Runs an activity inside the chat flow.
# Combines the shared activity_template.json with the per-activity slot data
# from activity_manifest.json to build a concrete ActivityInstance.
# Manages the loop: repeats the activity until loop_until condition is satisfied.
cat > lib/services/activity_service.dart << 'EOF'
// activity_service.dart
// Manages activity execution within the chat flow.
// buildInstance(activityId): loads activity_template.json + looks up activityId
//   in activity_manifest.json, merges them into an ActivityInstance.
// runLoop(instance): steps through all slots in the activity; on completion
//   checks the loop_until condition; if not met, resets and repeats.
// Reports completion back to flow_service so the course flow can advance.
// All slot content (quiz, video, audio IDs) come from the manifest — not hardcoded.
EOF

# Loads audio assets, caches them in Isar as bytes, and plays them.
# Works on web (using HTML audio element via js interop) and native (just_audio).
# Never re-downloads an audio file once cached.
cat > lib/services/audio_service.dart << 'EOF'
// audio_service.dart
// Manages prerecorded audio playback for flow steps.
// play(audioId): resolves audio path via flow_resolver, checks Isar byte cache,
//   loads from assets if not cached, caches bytes, then plays.
// stop(): stops current playback.
// On web: plays via HTML <audio> element using dart:js_interop.
// On native: uses just_audio package.
// Audio bytes are cached forever in Isar — never re-read from bundle after first load.
EOF

# The unified cache interface used by all services.
# Wraps Isar collections with typed get/set/delete helpers.
# All cache operations go through here — never call Isar directly from a service.
cat > lib/services/cache_service.dart << 'EOF'
// cache_service.dart
// The single cache access point for all services.
// Wraps Isar with typed helpers: getFlow, setFlow, getAudioBytes, setAudioBytes,
//   getProgress, setProgress, getProfiles, setProfiles.
// Lazy strategy: caller checks cache first; on miss, fetches then calls set.
// Flows and audio: stored forever (no expiry).
// Progress: written through on every update.
// Never access Isar directly from any service — always go through here.
EOF

# Reads and writes the student's progress through their course.
# Write-through: every update is saved to Isar AND sent to the backend.
# On app launch, loads from Isar first (instant), then reconciles with backend.
cat > lib/services/progress_service.dart << 'EOF'
// progress_service.dart
// Manages per-profile progress through the course flow.
// saveStep(profileId, stepIndex): writes to Isar + calls api_client to sync backend.
// markActivityComplete(profileId, activityId): adds to completedActivityIds.
// loadProgress(profileId): reads from Isar first; if missing, fetches from backend.
// Progress is keyed by profileId so each child's data is fully independent.
// Write-through on every update — progress loss on crash is unacceptable.
EOF

# =============================================================================
# FLUTTER — PROVIDERS (Riverpod)
# =============================================================================

mkdir -p lib/providers

# Auth state: unauthenticated, otp_sent, otp_verified, password_required, authenticated.
# Exposes methods called by login_screen, otp_screen, and password_screen.
cat > lib/providers/auth_provider.dart << 'EOF'
// auth_provider.dart
// Riverpod StateNotifier for authentication state.
// States: unauthenticated → otpSent → otpVerified → passwordRequired → authenticated.
// Methods: requestOtp, verifyOtp, setPassword, loginWithPassword, logout.
// Delegates to auth_service.dart for all logic.
// On authenticated: triggers profile_provider to fetch profiles.
EOF

# Holds the list of profiles and which one is currently active.
# On setActive: writes profile ID to token_storage and triggers progress load.
cat > lib/providers/profile_provider.dart << 'EOF'
// profile_provider.dart
// Riverpod StateNotifier for student profile management.
// Holds: list of profiles fetched from backend, currently active profile.
// loadProfiles(): fetches via profile_service, caches in Isar.
// setActiveProfile(profileId): updates active profile, triggers progress load.
// Used by profile_select_screen and profile_switcher widget.
EOF

# The heart of the UI: holds the ordered list of ChatMessages shown in the chat.
# Receives new steps from flow_provider and translates them into ChatMessages.
# Also holds pending user input before it is submitted as an answer.
cat > lib/providers/chat_provider.dart << 'EOF'
// chat_provider.dart
// Riverpod StateNotifier — the source of truth for what is visible in the chat UI.
// Holds: List<ChatMessage> displayed in chat_message_list.dart.
// addBotMessage(step): converts a FlowStep into a ChatMessage and appends it.
// addUserMessage(text): appends the user's reply as a ChatMessage.
// clearSession(): resets the list when starting a new flow.
// Does not contain flow logic — it only manages the visual message list.
EOF

# Drives the active flow: loads it, tracks cursor, exposes current step.
# When a step is an activity, delegates to activity_provider.
# When a step completes, advances cursor and pushes next step to chat_provider.
cat > lib/providers/flow_provider.dart << 'EOF'
// flow_provider.dart
// Riverpod StateNotifier — drives the active flow execution.
// startFlow(flowId): loads the flow via flow_service, resets cursor, starts stepping.
// currentStep: exposes the FlowStep at the cursor for the chat screen to render.
// advance(userInput): records user input, evaluates branches, moves to next step.
// When step type is "activity": delegates to activity_provider and awaits completion.
// When flow is complete: notifies progress_provider to save, returns to home.
EOF

# Manages one activity's execution inside the course flow.
# Builds the ActivityInstance, runs slots as chat messages, manages the loop.
cat > lib/providers/activity_provider.dart << 'EOF'
// activity_provider.dart
// Riverpod StateNotifier — manages a single running activity.
// startActivity(activityId): builds ActivityInstance via activity_service.
// currentSlot: the slot currently being rendered in chat (quiz, video, audio, etc).
// submitSlot(answer): records the answer and advances to the next slot.
// When all slots done: evaluates loop_until condition.
//   If condition met → marks complete, notifies flow_provider.
//   If not met → resets to first slot and repeats (the loop).
EOF

# Plays audio for the current flow step.
# Exposes isPlaying, play(audioId), stop().
cat > lib/providers/audio_provider.dart << 'EOF'
// audio_provider.dart
// Riverpod StateNotifier for audio playback state.
// isPlaying: bool — reflects current playback state.
// play(audioId): delegates to audio_service; updates isPlaying.
// stop(): stops playback via audio_service; sets isPlaying false.
// Consumed by audio_player.dart widget and chat_bubble.dart for inline play buttons.
EOF

# Locale selection: default from device, overridable from settings screen.
# Persisted in SharedPreferences so it survives restarts.
cat > lib/providers/locale_provider.dart << 'EOF'
// locale_provider.dart
// Riverpod StateNotifier for the app locale.
// Supported: en, hi, mr, kn.
// Loads saved locale from SharedPreferences on init (defaults to device locale).
// setLocale(code): saves to SharedPreferences + updates the MaterialApp locale.
// Consumed by settings_screen.dart for the language selector UI.
EOF

# The active profile's progress through their course.
# Loaded by profile_provider when a profile is selected.
# Exposes current step index and completed activity IDs.
cat > lib/providers/progress_provider.dart << 'EOF'
// progress_provider.dart
// Riverpod StateNotifier for the active profile's course progress.
// Loaded from Isar on profile select, reconciled with backend in background.
// currentStepIndex: where in course_flow.json the student currently is.
// completedActivityIds: set of finished activity IDs.
// markStepComplete(index): updates local state + calls progress_service to save.
// Used by flow_provider to know where to resume the course flow.
EOF

# =============================================================================
# FLUTTER — SCREENS
# =============================================================================

mkdir -p lib/screens/splash
mkdir -p lib/screens/auth
mkdir -p lib/screens/profile_select
mkdir -p lib/screens/chat
mkdir -p lib/screens/passport
mkdir -p lib/screens/settings
mkdir -p lib/screens/public

# First screen shown on app launch.
# Checks for a stored JWT and active profile — routes accordingly.
# Shows app logo/branding while the check happens.
cat > lib/screens/splash/splash_screen.dart << 'EOF'
// splash_screen.dart
// First screen on launch. Shows app logo/branding.
// On init: reads token from token_storage.
//   No token → navigate to /landing or /login.
//   Token + no active profile → navigate to /profile-select.
//   Token + active profile → load progress, navigate to /chat.
// No user interaction — pure routing logic with a brief branded moment.
EOF

# Phone number entry. Minimal: just a phone field and a continue button.
# On submit: calls auth_provider.requestOtp → navigates to otp_screen.
cat > lib/screens/auth/login_screen.dart << 'EOF'
// login_screen.dart
// Phone number entry screen — the start of the auth flow.
// Single input: phone number with country code prefix.
// On continue: calls auth_provider.requestOtp(phone).
// On success: router navigates to /otp.
// On error: shows inline error message (not a dialog).
// No sign-up / no email — phone-only entry.
EOF

# OTP entry. Shows the phone number it was sent to.
# Auto-advances to password_screen on correct code.
# Shows resend option after 30 seconds.
cat > lib/screens/auth/otp_screen.dart << 'EOF'
// otp_screen.dart
// OTP verification screen.
// Shows: "Enter the code sent to +91 XXXXXXXX" with the phone number.
// 6-digit input — auto-submits when all 6 digits are entered.
// On verify: calls auth_provider.verifyOtp(phone, otp).
//   isNewUser true → navigate to /password (set password).
//   isNewUser false → navigate to /password (enter existing password).
// Resend button appears after 30 seconds; calls auth_provider.requestOtp again.
EOF

# Password screen: dual-purpose.
# If new user: "Create a password" with confirm field.
# If returning user: "Enter your password" single field.
# On success: auth is complete → navigate to /profile-select.
cat > lib/screens/auth/password_screen.dart << 'EOF'
// password_screen.dart
// Dual-purpose password screen.
// New user mode: two fields (password + confirm), calls auth_provider.setPassword.
// Returning user mode: single field, calls auth_provider.loginWithPassword.
// Mode is passed as a route parameter from otp_screen.
// On success: navigate to /profile-select.
// Password rules: minimum length only — no complexity requirements for now.
EOF

# Shows all student profiles under the phone account.
# Each profile is a card with name and avatar.
# "Add profile" button if fewer than max profiles exist.
# Selecting a profile calls profile_provider.setActiveProfile → navigates to /chat.
cat > lib/screens/profile_select/profile_select_screen.dart << 'EOF'
// profile_select_screen.dart
// Shown after login and when switching between child profiles.
// Displays a card grid of all student profiles under the phone account.
// Tap a profile → profile_provider.setActiveProfile(id) → navigate to /chat.
// "Add student" card → (future: create profile flow).
// Profiles are loaded from Isar cache first; background sync with backend.
// This screen is also navigated to from the profile_switcher widget in the header.
EOF

# The main screen. The chat interface.
# Everything happens here: onboarding, course flow, activities, quizzes.
# Renders ChatMessages from chat_provider in a scrollable list.
# Input area at the bottom handles text, option picks, and quiz submissions.
cat > lib/screens/chat/chat_screen.dart << 'EOF'
// chat_screen.dart
// The primary screen of the app — a chat interface that runs all flows.
// Renders: app_header (with profile switcher), chat_message_list, chat_input.
// On mount: checks progress_provider for current step, calls flow_provider.startFlow.
// chat_provider feeds the message list; flow_provider drives what comes next.
// Interactive slots (quiz, option_picker, video, submission) render as
//   special ChatMessage types inside the list — not as separate screens.
// Audio steps: auto-plays via audio_provider when message is added.
// User input at the bottom is context-aware: plain text, option buttons, or submit.
EOF

# The student's passport: shows name, avatar, course name, progress summary.
# Read-only view — no editing here (editing is a future concern).
cat > lib/screens/passport/passport_screen.dart << 'EOF'
// passport_screen.dart
// The student's identity card / progress overview screen.
// Shows: avatar, display name, course name, current progress (step X of Y),
//   completed activity count, and language preference.
// Read-only for now — no inline editing.
// Data sourced from profile_provider and progress_provider.
// Accessible from the app header or nav.
EOF

# Settings: two items only — language selector and logout.
# Language selector triggers locale_provider.setLocale.
# Logout calls auth_provider.logout → clears all state → navigates to /login.
cat > lib/screens/settings/settings_screen.dart << 'EOF'
// settings_screen.dart
// Settings screen — intentionally minimal.
// Language selector: shows supported locales (English, Hindi, Marathi, Kannada).
//   Tap a language → locale_provider.setLocale(code) → app relocalises instantly.
// Logout button: calls auth_provider.logout → clears token + active profile
//   → navigates to /login and removes all back-stack history.
// Nothing else here for now.
EOF

# Public landing page shown before login.
# Brief app description and a "Get started" button → /login.
cat > lib/screens/public/landing_screen.dart << 'EOF'
// landing_screen.dart
// Public-facing landing page — shown to unauthenticated users.
// Brief app description, tagline, and a "Get started" CTA → /login.
// No auth-gated content here.
// Kept deliberately simple: this is rarely seen after first install.
EOF

# =============================================================================
# FLUTTER — WIDGETS
# =============================================================================

mkdir -p lib/widgets/chat
mkdir -p lib/widgets/flow_components
mkdir -p lib/widgets/profile

# A single chat message bubble: bot (left-aligned) or user (right-aligned).
# Handles text content and an optional inline audio play button.
# Does not render interactive components — those use their own widget subtypes.
cat > lib/widgets/chat/chat_bubble.dart << 'EOF'
// chat_bubble.dart
// Renders one chat message bubble.
// Bot messages: left-aligned, bot avatar, app accent color background.
// User messages: right-aligned, neutral background.
// If the message has an audioId: shows a small play/pause button inline.
//   Tapping calls audio_provider.play(audioId).
// Does not handle quiz_card, option_picker, or video slots — those are
//   separate widget types rendered by chat_message_list based on message.type.
EOF

# The text input bar at the bottom of the chat screen.
# Context-aware: shows a text field when flow expects free text,
# or hides itself when the active slot uses option_picker or quiz_card instead.
cat > lib/widgets/chat/chat_input.dart << 'EOF'
// chat_input.dart
// The chat input area fixed at the bottom of chat_screen.
// Shows a text field + send button when the current flow step expects text input.
// Hidden when the active step uses option_picker, quiz_card, or video_slot
//   (those widgets handle their own submission).
// On send: calls flow_provider.advance(userInput).
// Handles keyboard show/hide gracefully on web and mobile.
EOF

# The scrollable message history. Renders the list of ChatMessages.
# Dispatches to the correct widget per message type.
# Auto-scrolls to bottom when new messages arrive.
cat > lib/widgets/chat/chat_message_list.dart << 'EOF'
// chat_message_list.dart
// Scrollable list of all ChatMessages in the current session.
// Reads from chat_provider.messages.
// Renders each message using the correct widget based on message.type:
//   "text" or "audio" → chat_bubble.dart
//   "quiz_card"       → quiz_card.dart
//   "option_picker"   → option_picker.dart
//   "video_slot"      → video_slot.dart
//   "submission_card" → submission_card.dart
// Auto-scrolls to the bottom whenever a new message is appended.
// Shows typing_indicator.dart while the next bot step is loading.
EOF

# Animated "bot is typing" indicator shown between flow steps.
# Three animated dots. Shown while flow_provider is loading the next step.
cat > lib/widgets/chat/typing_indicator.dart << 'EOF'
// typing_indicator.dart
// Animated typing indicator shown in the chat while the next step loads.
// Three pulsing dots, left-aligned like a bot bubble.
// Controlled by chat_provider.isLoading — shown when true, hidden when false.
// Pure animation — no logic.
EOF

# A multiple-choice quiz rendered as a card inside the chat.
# Shows the question text, answer options as tappable tiles.
# On selection: submits to activity_provider.submitSlot.
cat > lib/widgets/flow_components/quiz_card.dart << 'EOF'
// quiz_card.dart
// Renders a quiz question as an interactive card inside the chat message list.
// Shows: question text, answer options as tappable list tiles.
// Only one selection allowed (MCQ). Selected option highlights on tap.
// Confirm button submits the selection to activity_provider.submitSlot(answer).
// After submission: options become non-interactive (read-only result display).
// Quiz content (question, options, correct answer) comes from the activity slot data.
EOF

# Option picker: shows a set of bot-provided options the user taps to reply.
# Used for branching flow steps where user picks from a short list.
# Not a quiz — no right/wrong answer, just a flow direction choice.
cat > lib/widgets/flow_components/option_picker.dart << 'EOF'
// option_picker.dart
// Renders a set of tappable option buttons inside the chat.
// Used for flow branching steps — user picks a path, not a quiz answer.
// Options appear as rounded pill buttons below the bot message.
// On tap: selected option is echoed as a user ChatMessage, then
//   flow_provider.advance(selectedOption) is called.
// After selection: buttons disappear and are replaced by the echoed user message.
EOF

# Video slot rendered inside the chat.
# Shows a video player inline for the video step in an activity.
# Marks the slot as complete when the video finishes or user taps "continue".
cat > lib/widgets/flow_components/video_slot.dart << 'EOF'
// video_slot.dart
// Renders a video player inline inside the chat message list.
// The video URL/ID comes from the activity slot data resolved by activity_service.
// Uses video_player package (web + native compatible).
// On video end: auto-advances — calls activity_provider.submitSlot("video_complete").
// "Skip" / "Continue" button also available if video can be skipped.
EOF

# Submission card: shown when an activity requires a file upload or text submission.
# Handles text input, image capture, or both depending on slot config.
cat > lib/widgets/flow_components/submission_card.dart << 'EOF'
// submission_card.dart
// Renders a submission prompt inside the chat for activity submission slots.
// Slot config determines type: text, image, or text+image.
// Text: a multi-line input field with a submit button.
// Image: a camera/gallery picker (web uses file input, native uses image_picker).
// On submit: calls activity_provider.submitSlot(submissionData).
// After submission: card becomes read-only, shows a "Submitted ✓" confirmation.
EOF

# Inline audio player for flow steps that have audio content.
# Play/pause button with a simple progress bar.
# Does not handle full audio management — delegates to audio_provider.
cat > lib/widgets/flow_components/audio_player.dart << 'EOF'
// audio_player.dart
// Inline audio player widget embedded in a chat bubble or as a standalone card.
// Shows: play/pause button + a linear progress bar.
// Tapping play calls audio_provider.play(audioId).
// Tapping pause calls audio_provider.stop().
// Progress bar updates from audio_provider stream.
// Used by chat_bubble.dart (inline) and as a standalone card for audio-only steps.
EOF

# Structured input card for flow steps that need form-style input.
# Used for onboarding steps like "enter your name" or "enter your age".
cat > lib/widgets/flow_components/input_card.dart << 'EOF'
// input_card.dart
// Renders a structured input form as a chat card — used in onboarding flows.
// Supports: single text field, numeric field, date picker.
// Field type and label come from the flow step's input_config.
// On submit: validates input, calls flow_provider.advance(inputValue).
// After submission: field becomes read-only, value echoed as user message.
EOF

# Profile switcher dropdown/bottom sheet shown from the app header.
# Lists all profiles under the account. Tap a different one to switch.
# On switch: profile_provider.setActiveProfile → reloads progress → stays on /chat.
cat > lib/widgets/profile/profile_switcher.dart << 'EOF'
// profile_switcher.dart
// A dropdown or bottom sheet widget for switching the active student profile.
// Triggered from the app header (avatar tap or name tap).
// Lists all profiles from profile_provider.profiles.
// Tap a different profile → profile_provider.setActiveProfile(id)
//   → progress_provider reloads for new profile → chat_provider clears + resumes flow.
// Does not navigate away from chat_screen — the switch happens in place.
EOF

# Shared app header widget used across all authenticated screens.
# Shows app logo, active profile name/avatar, and a settings icon.
cat > lib/widgets/app_header.dart << 'EOF'
// app_header.dart
// Shared top header for authenticated screens.
// Left: app logo / name.
// Centre: active profile name (from profile_provider).
// Right: avatar thumbnail → tapping opens profile_switcher widget.
//        settings icon → navigates to /settings.
// Used on chat_screen, passport_screen, settings_screen.
EOF

# Shared bottom nav bar — minimal: chat, passport, settings.
cat > lib/widgets/app_nav.dart << 'EOF'
// app_nav.dart
// Shared bottom navigation bar for authenticated screens.
// Three items: Chat (home), Passport, Settings.
// Highlights the current route.
// Uses GoRouter to navigate — does not manage its own state.
EOF

# Reusable styled button used across all screens.
cat > lib/widgets/app_button.dart << 'EOF'
// app_button.dart
// Reusable primary action button used across all screens.
// Props: label, onPressed, isLoading (shows spinner when true), isDisabled.
// Uses app theme colors — no hardcoded values.
EOF

# Full-screen error view with a message and retry button.
cat > lib/widgets/error_view.dart << 'EOF'
// error_view.dart
// Full-screen error display used when a critical load fails.
// Shows: error icon, human-readable message, and a "Try again" button.
// The retry callback is passed in from the parent widget or provider.
EOF

# Full-screen loading view with a spinner. Shown during initial load.
cat > lib/widgets/loading_view.dart << 'EOF'
// loading_view.dart
// Full-screen loading indicator shown during initial data fetch or flow load.
// Simple centered spinner with an optional message string below it.
// Used by splash_screen and any screen waiting on a critical async operation.
EOF

# =============================================================================
# FLUTTER — L10N
# =============================================================================

mkdir -p lib/l10n

cat > lib/l10n/app_en.arb << 'EOF'
{
  "@@locale": "en",
  "appName": "App Name Here",
  "continueButton": "Continue",
  "sendOtp": "Send OTP",
  "verifyOtp": "Verify",
  "createPassword": "Create Password",
  "enterPassword": "Enter Password",
  "logout": "Logout",
  "language": "Language",
  "settings": "Settings",
  "passport": "Passport"
}
EOF

cat > lib/l10n/app_hi.arb << 'EOF'
{
  "@@locale": "hi"
}
EOF

cat > lib/l10n/app_mr.arb << 'EOF'
{
  "@@locale": "mr"
}
EOF

cat > lib/l10n/app_kn.arb << 'EOF'
{
  "@@locale": "kn"
}
EOF

# =============================================================================
# FLUTTER — ROOT
# =============================================================================

# The root MaterialApp widget. Configures GoRouter, locale, and Riverpod scope.
cat > lib/app.dart << 'EOF'
// app.dart
// Root widget of the Flutter app.
// Wraps MaterialApp.router with:
//   - GoRouter from router.dart
//   - Theme from app_theme.dart
//   - Locale from locale_provider.dart
//   - l10n delegates for en, hi, mr, kn
// ProviderScope is set up in main.dart above this.
EOF

# Entry point. Initialises Isar, loads the flow manifest, then runs the app.
cat > lib/main.dart << 'EOF'
// main.dart
// Flutter entry point.
// Before runApp:
//   1. WidgetsFlutterBinding.ensureInitialized()
//   2. Initialise Isar (open the database, register schemas)
//   3. Load flow_manifest.json via flow_index.dart into memory
//   4. Initialise cache_service with the open Isar instance
// Then: runApp(ProviderScope(child: App()))
// All subsequent initialisation (auth check, profile load) happens in splash_screen.
EOF

# =============================================================================
# ASSETS — FLOWS
# =============================================================================

mkdir -p assets/flows/onboarding
mkdir -p assets/flows/auth
mkdir -p assets/flows/course
mkdir -p assets/flows/activity
mkdir -p assets/audio
mkdir -p assets/content

# Master index of all flow IDs to their asset paths.
# Loaded once at startup by flow_index.dart.
# Add every new flow and audio file here — the resolver will not find it otherwise.
cat > assets/flows/flow_manifest.json << 'EOF'
{
  "_comment": "Master manifest — maps every flow ID and audio ID to its asset path. Loaded once at startup. Add new flows and audio files here.",
  "flows": {
    "onboarding_student": "assets/flows/onboarding/student_onboarding.json",
    "login_flow":         "assets/flows/auth/login_flow.json",
    "course_main":        "assets/flows/course/course_flow.json"
  },
  "activities": {
    "_comment": "Add each activity ID and its manifest entry key here",
    "activity_001": "assets/flows/activity/activity_manifest.json#activity_001"
  },
  "audio": {
    "_comment": "Map audio IDs to their file paths in assets/audio/",
    "audio_welcome": "assets/audio/welcome.mp3"
  }
}
EOF

# Onboarding flow for a new student.
# Runs entirely inside the chat interface on first login.
# Steps: greeting → ask name → ask grade → confirm → done.
cat > assets/flows/onboarding/student_onboarding.json << 'EOF'
{
  "_comment": "Student onboarding flow — runs in the chat screen on first login. Each step is rendered as a chat interaction. Collect: name, grade. End by launching the course flow.",
  "id": "onboarding_student",
  "version": 1,
  "steps": [
    {
      "_comment": "Step template — type can be: message, input, option_picker, activity, audio",
      "id": "step_001",
      "type": "message",
      "audioId": "audio_welcome",
      "content": { "en": "Welcome! I am your learning companion." },
      "next": "step_002"
    },
    {
      "id": "step_002",
      "type": "input",
      "input_config": { "field": "studentName", "input_type": "text" },
      "content": { "en": "What is your name?" },
      "next": "step_003"
    }
  ]
}
EOF

# The main course flow for one student.
# A linear sequence of steps that can include messages, audio, and activity references.
# Activity steps pause the course and run the activity loop, then resume here.
cat > assets/flows/course/course_flow.json << 'EOF'
{
  "_comment": "Main course flow. Linear sequence. Step type 'activity' pauses this flow, runs the named activity by ID via activity_service, then resumes at the next step. Add as many steps as needed.",
  "id": "course_main",
  "version": 1,
  "steps": [
    {
      "id": "course_step_001",
      "type": "message",
      "audioId": "audio_welcome",
      "content": { "en": "Let us begin today's lesson." },
      "next": "course_step_002"
    },
    {
      "id": "course_step_002",
      "type": "activity",
      "activityId": "activity_001",
      "next": "course_step_003"
    }
  ]
}
EOF

# The reusable activity template.
# Every activity runs through this shell — slots are filled from activity_manifest.json.
# Slot types: intro_message, audio, video, quiz, submission, outro_message.
cat > assets/flows/activity/activity_template.json << 'EOF'
{
  "_comment": "Reusable activity shell. Slots are placeholders filled at runtime from activity_manifest.json using the activity ID. Never put activity-specific content here.",
  "template_version": 1,
  "slots": [
    { "slot": "intro_message", "type": "message",    "audioId_ref": "introAudioId",  "content_ref": "introContent" },
    { "slot": "video",         "type": "video_slot", "video_ref":   "videoId" },
    { "slot": "quiz",          "type": "quiz_card",  "quiz_ref":    "quizData" },
    { "slot": "submission",    "type": "submission_card", "config_ref": "submissionConfig" },
    { "slot": "outro_message", "type": "message",    "audioId_ref": "outroAudioId",  "content_ref": "outroContent" }
  ],
  "loop_until": "submission_complete"
}
EOF

# Per-activity data that fills the template slots.
# Add one entry per activity ID. activity_service combines this with the template.
cat > assets/flows/activity/activity_manifest.json << 'EOF'
{
  "_comment": "Per-activity slot data. Each key is an activity ID. activity_service loads the template + the matching entry here and merges them into an ActivityInstance.",
  "activity_001": {
    "introAudioId":  "audio_act_001_intro",
    "introContent":  { "en": "Let us watch a short video." },
    "videoId":       "video_act_001",
    "quizData": {
      "question":    { "en": "What did you learn from the video?" },
      "options":     [
        { "id": "a", "text": { "en": "Option A" } },
        { "id": "b", "text": { "en": "Option B" } }
      ],
      "correctId":   "a"
    },
    "submissionConfig": { "type": "text", "prompt": { "en": "Write what you understood." } },
    "outroAudioId":  "audio_act_001_outro",
    "outroContent":  { "en": "Great work! Let us move on." }
  }
}
EOF

# =============================================================================
# CLOUDFLARE WORKER
# =============================================================================

echo "=> Creating Cloudflare Worker scaffold..."

mkdir -p worker/src
mkdir -p worker/.wrangler/cache
mkdir -p worker/.wrangler/tmp

# =============================================================================
# WORKER — wrangler.toml
# =============================================================================

# Wrangler config: name, entry point, D1 database binding, and KV namespace.
# D1 is used for users, profiles, and progress.
# KV is used for OTP storage (short TTL) and session token blacklisting.
cat > worker/wrangler.toml << 'EOF'
# wrangler.toml
# Cloudflare Worker configuration.
# name: your worker name — change before deploy.
# main: entry point is src/worker.js.
# D1 database: bound as DB — holds users, profiles, progress tables.
# KV namespace: bound as KV — holds OTPs (short TTL) and token blacklist.
# Set SMS provider secrets via: wrangler secret put SMS_API_KEY

name = "your-worker-name"
main = "src/worker.js"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding  = "DB"
database_name = "your-db-name"
database_id   = "your-d1-database-id"

[[kv_namespaces]]
binding    = "KV"
id         = "your-kv-namespace-id"
preview_id = "your-kv-preview-id"
EOF

# =============================================================================
# WORKER — package.json
# =============================================================================

cat > worker/package.json << 'EOF'
{
  "name": "your-worker-name",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev":    "wrangler dev",
    "deploy": "wrangler deploy",
    "db:migrate": "wrangler d1 execute DB --file=schema.sql"
  },
  "devDependencies": {
    "wrangler": "^3.0.0"
  }
}
EOF

# =============================================================================
# WORKER — schema.sql
# =============================================================================

# D1 database schema.
# Tables: accounts (one per phone), profiles (one per student/child),
#         progress (one per profile, stores current step + completed activities),
#         sessions (JWT tracking for logout/blacklist).
cat > worker/schema.sql << 'EOF'
-- schema.sql
-- D1 database schema for the Cloudflare Worker.
--
-- accounts: one row per phone number. Stores hashed password.
--   phone is the primary key — no email, no username.
--
-- profiles: one row per student under an account.
--   Multiple profiles share one account (phone).
--   Each profile has its own courseId and display info.
--
-- progress: one row per profile.
--   Stores currentStepIndex and completedActivityIds (JSON array).
--   Updated on every step completion.
--
-- sessions: tracks issued JWTs for logout blacklisting.
--   jti (JWT ID claim) is stored; on logout, jti is added here.
--   Worker checks this table on every authenticated request.

CREATE TABLE IF NOT EXISTS accounts (
  phone         TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS profiles (
  profile_id    TEXT PRIMARY KEY,
  phone         TEXT NOT NULL REFERENCES accounts(phone),
  display_name  TEXT NOT NULL,
  avatar_index  INTEGER NOT NULL DEFAULT 0,
  course_id     TEXT NOT NULL,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS progress (
  profile_id              TEXT PRIMARY KEY REFERENCES profiles(profile_id),
  current_step_index      INTEGER NOT NULL DEFAULT 0,
  completed_activity_ids  TEXT NOT NULL DEFAULT '[]',
  last_active_at          INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS sessions (
  jti        TEXT PRIMARY KEY,
  phone      TEXT NOT NULL,
  revoked    INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);
EOF

# =============================================================================
# WORKER — src/worker.js
# =============================================================================

# The main Worker entry point.
# Handles fetch events, applies CORS, rate limiting, and routes requests.
cat > worker/src/worker.js << 'EOF'
// worker.js
// Cloudflare Worker entry point.
// Handles all incoming fetch events.
// Pipeline for every request:
//   1. cors.js — apply CORS headers; handle preflight OPTIONS.
//   2. ratelimit.js — check request rate per IP; return 429 if exceeded.
//   3. routes.js — match method + path to the correct handler.
// All route handlers live in routes.js.
// DB and KV bindings are passed from env into handlers via routes.js.
EOF

# =============================================================================
# WORKER — src/routes.js
# =============================================================================

# Declares all API routes and maps them to handler functions.
# Auth routes: /auth/otp, /auth/verify, /auth/password, /auth/login, /auth/logout.
# Profile routes: /profiles (GET), /profiles/:id (GET).
# Progress routes: /progress/:profileId (GET, POST).
cat > worker/src/routes.js << 'EOF'
// routes.js
// Declares all API route handlers.
// Route table maps [METHOD, path pattern] to an async handler function.
// Authenticated routes run auth.js validateToken before the handler.
//
// Public routes (no token needed):
//   POST /auth/otp       → request OTP SMS for a phone number
//   POST /auth/verify    → verify OTP, return JWT + isNewUser flag
//   POST /auth/password  → set password (new user) or login (returning)
//
// Authenticated routes (JWT required):
//   POST /auth/logout        → revoke JWT (add jti to sessions table)
//   GET  /profiles           → list all profiles for the authed phone
//   GET  /progress/:profileId → fetch progress for a profile
//   POST /progress/:profileId → save/update progress for a profile
//
// All handlers receive: (request, env, ctx, params)
EOF

# =============================================================================
# WORKER — src/auth.js
# =============================================================================

# OTP generation and verification logic.
# Stores OTP in KV with a 5-minute TTL.
# On verify: compares OTP, checks TTL, deletes from KV, returns JWT.
cat > worker/src/auth.js << 'EOF'
// auth.js
// Handles OTP send, OTP verify, password set/check, and token validation.
//
// sendOtp(phone, env):
//   Generates a 6-digit OTP, stores in KV as "otp:{phone}" with 300s TTL.
//   Calls the SMS provider API (key from env.SMS_API_KEY).
//
// verifyOtp(phone, otp, env):
//   Reads "otp:{phone}" from KV. Compares. Deletes on match.
//   Checks if account exists → sets isNewUser flag.
//   Returns signed JWT via jwt.js.
//
// setPassword(phone, password, env):
//   Hashes password with bcrypt (or SubtleCrypto PBKDF2 for Workers).
//   Upserts account row in D1.
//
// loginWithPassword(phone, password, env):
//   Fetches account from D1. Compares hash. Returns signed JWT.
//
// validateToken(request, env):
//   Extracts Bearer token. Verifies signature via jwt.js.
//   Checks jti against sessions table (blacklist). Returns phone claim.
EOF

# =============================================================================
# WORKER — src/jwt.js
# =============================================================================

# JWT sign and verify using the Web Crypto API (Workers-compatible).
# Signs with HS256. Claims: sub (phone), jti, iat, exp.
cat > worker/src/jwt.js << 'EOF'
// jwt.js
// JWT creation and verification using the Web Crypto API (no npm deps).
// Workers do not support Node crypto — uses SubtleCrypto exclusively.
//
// sign(payload, secret):
//   Creates a HS256 JWT. Payload includes: sub (phone), jti (uuid), iat, exp.
//   Returns the JWT string.
//
// verify(token, secret):
//   Verifies the HS256 signature. Checks exp claim.
//   Returns the decoded payload or throws on invalid/expired token.
//
// The secret comes from env.JWT_SECRET (set via: wrangler secret put JWT_SECRET).
EOF

# =============================================================================
# WORKER — src/cors.js
# =============================================================================

# CORS headers applied to every response.
# Allows the Flutter web app origin and the mobile app (null origin / capacitor).
# Handles OPTIONS preflight requests immediately.
cat > worker/src/cors.js << 'EOF'
// cors.js
// Applies CORS headers to every outgoing response.
// Allowed origins: your Flutter web app domain + localhost for dev.
// Also allows null origin for Flutter native apps (which send no origin header).
//
// applyCors(response, request): adds Access-Control headers to a Response.
// handlePreflight(request): returns a 204 response for OPTIONS preflight.
//
// Call handlePreflight first in worker.js before routing.
// Wrap every handler response with applyCors before returning.
EOF

# =============================================================================
# WORKER — src/d1.js
# =============================================================================

# Typed helper functions for all D1 database operations.
# No raw SQL outside this file — all queries live here.
cat > worker/src/d1.js << 'EOF'
// d1.js
// All D1 database queries in one place — no raw SQL anywhere else.
//
// Account queries:
//   getAccount(phone, db)      → row or null
//   upsertAccount(phone, hash, db)
//
// Profile queries:
//   getProfilesByPhone(phone, db) → array of profile rows
//   getProfile(profileId, db)     → single profile row or null
//
// Progress queries:
//   getProgress(profileId, db)    → progress row or null
//   upsertProgress(profileId, stepIndex, completedIds, db)
//
// Session queries:
//   insertSession(jti, phone, db)
//   revokeSession(jti, db)
//   isSessionRevoked(jti, db)     → boolean
EOF

# =============================================================================
# WORKER — src/ratelimit.js
# =============================================================================

# Per-IP rate limiting using KV.
# OTP endpoints: stricter limit (5 per hour per IP).
# General endpoints: looser limit (60 per minute per IP).
cat > worker/src/ratelimit.js << 'EOF'
// ratelimit.js
// IP-based rate limiting backed by Cloudflare KV.
//
// checkLimit(ip, route, env):
//   Reads counter from KV key "rl:{route}:{ip}".
//   OTP routes (/auth/otp): max 5 requests per hour.
//   All other routes: max 60 requests per minute.
//   Increments counter. Sets TTL on first write.
//   Returns { allowed: bool, remaining: int }.
//
// If not allowed: caller returns 429 Too Many Requests.
// KV TTL handles automatic counter reset — no cron needed.
EOF

# =============================================================================
# WORKER — .wrangler placeholder files
# =============================================================================

cat > worker/.wrangler/cache/cf.json << 'EOF'
{}
EOF

echo ""
echo "======================================================"
echo " Scaffold complete."
echo ""
echo " Flutter app:         lib/  assets/"
echo " Cloudflare Worker:   worker/"
echo ""
echo " Next steps:"
echo "   1. cd worker && npm install"
echo "   2. Create D1 database: wrangler d1 create your-db-name"
echo "   3. Create KV namespace: wrangler kv:namespace create KV"
echo "   4. Update worker/wrangler.toml with real IDs from steps 2-3"
echo "   5. Run migration: npm run db:migrate"
echo "   6. Set secrets: wrangler secret put JWT_SECRET"
echo "                   wrangler secret put SMS_API_KEY"
echo "   7. Dev worker: npm run dev"
echo "   8. Flutter: add isar, riverpod, go_router, just_audio to pubspec.yaml"
echo "   9. Register all asset paths in pubspec.yaml under flutter: assets:"
echo "======================================================"
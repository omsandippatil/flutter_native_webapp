# TAP App — Project Structure Reference

Two codebases: **`worker/`** (Cloudflare Worker backend, JS) and **`lib/`** (Flutter app, Dart). Structure is **feature-first**: each feature owns its `data/application/domain/presentation/models`; cross-feature code lives in `core/`, `domain/` (shared models), `shared/`, `providers/`.

---

## 1. `worker/` — Cloudflare Worker API Gateway

```
worker/src/
├── index.js              Entry point — routes 2 AI endpoints directly, delegates rest to route_table
├── ai/
│   └── groq_client.js     Raw fetch wrappers for Groq API: callGroq, callGroqVision, callGroqAudioTranscription
├── auth/
│   ├── jwt.js              HS256 JWT sign/verify (Web Crypto), access(90d)/reset(10min) token helpers
│   └── auth_guard.js       validateAccessToken/validateResetToken, token-refresh check, 401/403 responses
├── handlers/
│   ├── tap_buddy_chat.js       POST /tapbuddy/chat — chatbot system prompt + learner context → Groq
│   └── submission_review.js    POST /submission-review/review — grades text/image/audio submissions via Groq (JSON mode, retry-on-truncation)
├── middleware/
│   ├── cors.js             Origin allowlist + CORS headers on every response
│   └── rate_limit.js       KV-backed per-IP buckets: otp(5/hr), groq(20/hr), default(60/min)
└── routes/
    └── route_table.js      Declarative ROUTES[] (path→Frappe backend method), JWT auth injection, proxies to FRAPPE_BASE_URL
```
**Flow:** request → CORS/rate-limit → `/tapbuddy/*` & `/submission-review/*` handled locally (call Groq) → everything else proxied to Frappe backend via `route_table.js`.

---

## 2. `lib/` — Flutter App

### 2.1 `core/` — app-wide infrastructure (no feature knowledge)

| Folder | File | Purpose |
|---|---|---|
| `assets/` | `asset_loader.dart` | Generic bundle-asset JSON loader (loadJson/loadJsonList/loadRawString) |
| `constants/` | `app_constants.dart` | Worker base URL, supported languages, flow asset path builders |
| `flows/` | `flow_manifest.dart` | Model: which languages exist per flow file |
| | `flow_manifest_repository.dart` | Loads/caches the manifest (asset → local cache → memory) |
| | `flow_repository.dart` | Resolves+loads one flow JSON (with language fallback to `en`) |
| | `flow_providers.dart` | Riverpod wiring for the two repos above |
| `localization/` | `language_provider.dart` | Riverpod `Notifier<String>` for current language, persisted to cache |
| `network/` | `api_endpoints.dart` | All REST path string constants |
| | `http_client.dart` | Dio wrapper: injects auth token, captures refreshed token, maps 401→`AuthException`, 429→`RateLimitedException` |
| `router/` | `app_router.dart` | GoRouter: route table + auth/onboarding/welcome redirect logic |
| `storage/` | `cache_keys.dart` | Central builder of all local-cache key strings (namespaced `v2:...`) |
| | `local_cache.dart` | Hive-backed KV cache: generic get/set + domain helpers (profiles index, learner invalidation) |
| | `secure_token_store.dart` | flutter_secure_storage wrapper: JWT/phone/admin-code |
| `theme/` | `app_theme.dart` | Colors, text styles, button/input themes, radii |
| | `app_spacing.dart` | Responsive spacing/breakpoint scale (`AppSpacingScale`) |

### 2.2 `domain/` — shared business models/repos/providers (used by 2+ features)

```
domain/
├── auth/        data/auth_repository.dart (login, OTP, session persist)
│                models/auth_session.dart
│                providers/auth_providers.dart
├── course/      data/course_asset_source.dart   (reads bundled course JSON)
│                data/course_repository.dart     (ProgramContentRepository — cache+asset orchestration)
│                data/json_cache_loader.dart      (generic cache-or-fetch helper, DataLoader)
│                models/course_detail.dart        (Course/Unit/Video/Quiz/Assignment models, compact JSON keys)
│                models/course_index_entry.dart
│                models/course_exceptions.dart
│                providers/course_providers.dart
├── learner/     calculations/local_archetype_calculator.dart (offline engagement-archetype heuristic)
│                data/learner_state_repository.dart  (★ core domain repo: fetch/cache/merge learner XP, progress, local-pending-progress sync, conflict handling)
│                models/learner_state.dart           (big aggregate model + weekly-limit extension)
│                models/enrollment.dart, achievement.dart, learner_archetype.dart, learner_profile_fields.dart
│                providers/learner_state_providers.dart
└── profile/     data/profile_repository.dart     (profiles list/search/select, onboarding completion)
                 data/roster_cache_sync.dart       (patches cached roster/profile lists in place)
                 models/active_profile.dart, profile_summary.dart
                 providers/profile_providers.dart
```

### 2.3 `features/` — one folder per screen/flow, each with its own mini-layers

**Pattern per feature:** `application/` (controllers, providers, orchestration) → `data/` (repos talking to API/cache) → `domain/` (feature-local pure logic) → `models/` (feature-local models) → `presentation/` (screens + `widgets/`).

```
features/
├── auth/presentation/
│   ├── login_screen.dart            Phone → password/create-password flow, routes to profile-select or home
│   └── profile_select_screen.dart   Grid of student profiles for a phone number
│
├── onboarding/
│   ├── application/
│   │   ├── onboarding_flow_controller.dart     ★ ChangeNotifier driving the step-by-step chat flow (messages, steps, form state)
│   │   ├── onboarding_component_registry.dart  Maps flow-step JSON → Flutter widget (track/course pickers, forms)
│   │   └── onboarding_session_service.dart     Enroll, commit profile updates, mark onboarding complete
│   ├── data/onboarding_flow_repository.dart    Loads onboarding_flow.json (steps)
│   ├── models/onboarding_flow_step.dart, onboarding_message.dart
│   └── presentation/
│       ├── onboarding_runtime.dart / onboarding_screen.dart
│       └── widgets/ (chat bubbles, track/course picker cards, forms, celebration cards)
│
├── classroom/                                  ★ largest feature — the "class session" chat/activity engine
│   ├── application/
│   │   ├── classroom_bootstrap_provider.dart    Resolves which unit/stage to resume on entry
│   │   ├── classroom_session_controller.dart    ★★ huge ChangeNotifier: video→submission→quiz state machine, XP accounting, retries
│   │   ├── classroom_providers.dart             Wires bootstrap+flow+repos into the controller
│   │   ├── activity_flow_provider.dart          Loads activity_flow.json for current language
│   │   └── submission_review_provider.dart
│   ├── data/
│   │   ├── session_window_repository.dart       Tracks weekly completed-unit keys (local cache)
│   │   └── submission_review_repository.dart    Calls /submission-review/review, caches result
│   ├── domain/archetype_step_selector.dart      Picks assignment/step variant by learner archetype
│   ├── models/ (activity_flow, classroom_message, progress_stage, session_window, submission_answer/review)
│   └── presentation/
│       ├── classroom_screen.dart                Top-level screen: chat list + reveal rail (desktop) layout
│       └── widgets/chat, checkpoint, quiz, reveal, states, submission, video  (one subfolder per UI concern)
│
├── home/
│   ├── models/learning_dashboard.dart           LearningStage enum + dashboard aggregate models
│   ├── providers/home_dashboard_provider.dart   Combines learner state + course + session window → dashboard
│   └── presentation/home_screen.dart + widgets/ (one card per stage: start/send/quiz/completed, buddy art)
│
├── passport/presentation/passport_screen.dart   Points/gems/streak + achievement flip-cards
│
├── profile_settings/
│   ├── application/ (profile_form_controller, profile_settings_actions, about_tap_loader)
│   ├── models/profile_tab.dart
│   └── presentation/settings_screen.dart + widgets/ (profile details, switch-profile dialog, about, settings tab)
│
├── tap_buddy/                                   Slide-out AI chat assistant panel
│   ├── data/tap_buddy_chat_repository.dart       Calls /tapbuddy/chat, persists transcript to cache
│   ├── models/chat_turn.dart
│   ├── providers/ (chat repo + tap_buddy_context_provider — builds learner context sent to AI)
│   └── presentation/tap_buddy_panel.dart
│
├── splash/presentation/splash_screen.dart
├── welcome/presentation/welcome_screen.dart     "Welcome back" interstitial after login
└── error/presentation/error_screen.dart
```

### 2.4 `shared/` — cross-feature reusable UI

```
shared/widgets/
├── app_shell.dart     AppNav (bottom nav + TapBuddy slide-over scope)
├── app_header.dart     Reusable top header (two modes: back-nav vs. greeting/stats)
├── loading_view.dart
└── error_view.dart
```

### 2.5 `providers/` — top-level DI roots

```
providers/
├── http_client_provider.dart    Provides HttpClient + SecureTokenStore
└── local_cache_provider.dart    Provides LocalCache (opens Hive boxes)
```

### 2.6 Entry points

| File | Purpose |
|---|---|
| `lib/main.dart` | `runApp(ProviderScope(child: App()))` |
| `lib/app.dart` | `MaterialApp.router` wiring theme + router |

---

## 3. Layer Responsibilities (applies to every feature)

| Layer | Responsibility | Depends on |
|---|---|---|
| **models/** | Plain data classes, `fromJson/toJson`, no logic beyond parsing | nothing |
| **data/** | Talks to `HttpClient`/`LocalCache`/asset bundle; caching strategy lives here | models, core |
| **domain/** (feature-local) | Pure business rules (e.g. archetype→step selection) | models |
| **application/** | Orchestrates data+domain into UI-ready state; Riverpod providers & `ChangeNotifier` controllers | data, domain, domain/ (shared) |
| **presentation/** | Widgets only; reads `application/` via `ConsumerWidget`/`AnimatedBuilder` | application |

## 4. Key Cross-Cutting Concepts

- **Caching:** `LocalCache` (Hive) is the single source of truth for offline state; `CacheKeys` centralizes every key format. Most repos follow *cache → network → write-back* pattern.
- **Auth:** JWT stored in `SecureTokenStore`; `HttpClient` auto-attaches it and captures silently-refreshed tokens from any response body's `token` field.
- **Offline progress:** `learner_state_repository.dart` + `session_window_repository.dart` let a unit's video/submission/quiz progress be cached locally and synced later (`ProgressConflictException` handles server disagreement).
- **Flows (JSON-driven UX):** Onboarding and classroom chat scripts live in `assets/flows/<lang>/...json`, loaded via `core/flows/`, interpreted by each feature's own controller.
- **AI integration:** Only two endpoints hit Groq (`/tapbuddy/chat`, `/submission-review/review`), both proxied/rate-limited by the Worker — Flutter never calls Groq directly.
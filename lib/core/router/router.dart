import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/splash/splash_screen.dart';
import '../../screens/error/error_screen.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/auth/profile_select/profile_select_screen.dart';
import '../../screens/auth/onboarding/onboarding_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/class/class_screen.dart';
import '../../screens/passport/passport_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/content/video/video_screen.dart';
import '../../screens/content/submission/submission_screen.dart';
import '../../screens/content/quiz/quiz_screen.dart';
import '../../screens/welcome/welcome_screen.dart';
import '../../providers/profile_provider.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String profileSelect = '/profile-select';
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String classroom = '/classroom';
  static const String passport = '/passport';
  static const String profile = '/profile';
  static const String video = '/video';
  static const String submission = '/submission';
  static const String quiz = '/quiz';
  static const String error = '/error';

  static Page<void> page(Widget child) => NoTransitionPage<void>(child: child);
}

/// Bridges `activeProfileProvider` (a Riverpod [FutureProvider]) into a
/// [Listenable] that GoRouter's `refreshListenable` can subscribe to. Every
/// time the active profile changes — login, logout, or onboarding
/// completion — this notifies, and GoRouter re-runs `redirect` immediately
/// instead of waiting for the next manual navigation call.
///
/// Also tracks whether `activeProfileProvider` has ever resolved to a value
/// at least once. This is intentionally separate from `AsyncValue.hasValue`,
/// because `ref.invalidate` on a plain `FutureProvider` re-emits a bare
/// `AsyncLoading()` with `hasValue: false` even though the provider held
/// valid data moments before — `redirect` needs to tell "true first load"
/// apart from "refetching after our own invalidate" so it doesn't bounce an
/// already-authenticated user back to `/splash` mid-login.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(this._ref) {
    _sub = _ref.listen<AsyncValue<dynamic>>(
      activeProfileProvider,
      (previous, next) {
        if (next.hasValue || next.hasError) {
          hasResolvedOnce = true;
        }
        notifyListeners();
      },
      fireImmediately: false,
    );
    // The listener above only reacts to *future* transitions. If
    // `activeProfileProvider` already resolved before this listenable was
    // constructed (e.g. this router/listenable got recreated after the
    // provider was already warm), that past resolution would otherwise be
    // missed entirely and `hasResolvedOnce` would stay false forever,
    // permanently trapping `redirect` on the first-load `/splash` guard.
    // Seed it from the provider's current value so a late-attached
    // listener still counts an already-resolved state as resolved.
    final current = _ref.read(activeProfileProvider);
    if (current.hasValue || current.hasError) {
      hasResolvedOnce = true;
    }
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<dynamic>> _sub;

  bool hasResolvedOnce = false;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Routes that a fully logged-in, onboarded user should never land on.
/// Hitting any of these while authenticated redirects straight to /home
/// (or /welcome, once per cold start — see `_WelcomeGate` below).
const Set<String> _authOnlyRoutes = {
  AppRoutes.splash,
  AppRoutes.login,
  AppRoutes.onboarding,
  AppRoutes.profileSelect,
};

/// Routes reachable without a completed profile — i.e. the auth funnel
/// itself. Anything outside this set requires a logged-in, onboarded user.
const Set<String> _publicRoutes = {
  AppRoutes.splash,
  AppRoutes.login,
  AppRoutes.onboarding,
  AppRoutes.profileSelect,
  AppRoutes.error,
};

/// Tracks whether the "Welcome Back" screen has already been shown once
/// during this app process's lifetime. Deliberately in-memory (not
/// persisted to disk/cache) — the requirement is "every cold start", and a
/// fresh `ProviderScope` on process restart already gives that for free.
///
/// This is a `StateProvider<bool>` rather than a mutable field on a plain
/// object: mutating a field directly (`someProvider.read(ref).shown = true`)
/// does not go through Riverpod's notification system, so nothing watching
/// or listening reacts to it. Using `StateProvider` means setting `.state`
/// is a real state change, which keeps this consistent with the rest of
/// the auth-state plumbing that `_AuthRefreshListenable` depends on.
final _welcomeGateProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final activeProfileAsync = ref.read(activeProfileProvider);
      final target = state.matchedLocation;

      // True first load only: the provider has never resolved even once
      // since this router/listenable was created. Keep the splash screen
      // up rather than guessing where to send the user.
      if (activeProfileAsync.isLoading &&
          !activeProfileAsync.hasValue &&
          !refreshListenable.hasResolvedOnce) {
        return target == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // A refetch is in flight (e.g. right after login/logout/onboarding
      // invalidates the provider) but we've resolved at least once before.
      // Don't redirect off the current route on stale/incomplete data —
      // wait for this same refetch to settle and re-run `redirect` again
      // rather than bouncing the user through `/splash` or back to
      // `/login` based on a snapshot that's already out of date.
      if (activeProfileAsync.isLoading && !activeProfileAsync.hasValue) {
        return null;
      }

      // If the profile lookup itself failed, send the user to the auth
      // funnel rather than trapping them on a dead splash screen.
      if (activeProfileAsync.hasError) {
        return _publicRoutes.contains(target) && target != AppRoutes.splash
            ? null
            : AppRoutes.login;
      }

      final profile = activeProfileAsync.value;
      final loggedIn = profile != null;
      final onboarded = loggedIn && (profile.onboardingCompleted == true);

      if (!loggedIn) {
        // Logged out: the auth funnel (login, profile-select, onboarding)
        // and the error screen are reachable, but `/` (splash) is not a
        // valid resting place once the profile lookup has resolved — it's
        // only meant to be shown *during* that first load (handled by the
        // guard above). Without this, a resolved `AsyncData(null)` on
        // `target == '/'` fell through to "stay here" since splash was
        // included in `_publicRoutes`, leaving a logged-out user stuck on
        // splash forever even though resolution succeeded.
        if (target != AppRoutes.splash && _publicRoutes.contains(target)) return null;
        return AppRoutes.login;
      }

      if (!onboarded) {
        // Logged in but hasn't finished onboarding: pin them to onboarding
        // until it's done, but still allow the error screen through.
        if (target == AppRoutes.onboarding || target == AppRoutes.error) return null;
        return AppRoutes.onboarding;
      }

      // Fully logged in and onboarded. First time this app process has
      // resolved to that state, route through Welcome Back once; every
      // subsequent redirect this session goes straight to /home.
      final welcomeShown = ref.read(_welcomeGateProvider);
      if (!welcomeShown) {
        if (target == AppRoutes.welcome) return null;
        if (_authOnlyRoutes.contains(target) || target == AppRoutes.home) {
          return AppRoutes.welcome;
        }
        return null;
      }

      // Welcome already shown this session: treat it like the rest of the
      // auth-only funnel and bounce straight to /home.
      if (_authOnlyRoutes.contains(target) || target == AppRoutes.welcome) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => AppRoutes.page(const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => AppRoutes.page(const AuthCheckScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            AppRoutes.page(const ConversationalOnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.profileSelect,
        pageBuilder: (context, state) => AppRoutes.page(
          ProfileSelectScreen(
            phone: state.uri.queryParameters['phone'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) => AppRoutes.page(
          WelcomeBackScreen(
            onDone: () => ref.read(_welcomeGateProvider.notifier).state = true,
          ),
        ),
      ),
      // Home is the app's root once authenticated.
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => AppRoutes.page(const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.classroom,
        pageBuilder: (context, state) => AppRoutes.page(const ClassScreen()),
      ),
      GoRoute(
        path: AppRoutes.passport,
        pageBuilder: (context, state) => AppRoutes.page(const PassportScreen()),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => AppRoutes.page(const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.video,
        pageBuilder: (context, state) => AppRoutes.page(const VideoScreen()),
      ),
      GoRoute(
        path: AppRoutes.submission,
        pageBuilder: (context, state) => AppRoutes.page(const SubmissionScreen()),
      ),
      GoRoute(
        path: AppRoutes.quiz,
        pageBuilder: (context, state) => AppRoutes.page(const QuizScreen()),
      ),
      GoRoute(
        path: AppRoutes.error,
        pageBuilder: (context, state) => AppRoutes.page(const ErrorScreen()),
      ),
    ],
  );
});

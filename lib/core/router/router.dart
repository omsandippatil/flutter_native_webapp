import 'package:flutter/widgets.dart';
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

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String profileSelect = '/profile-select';
  static const String home = '/home';
  static const String classroom = '/classroom';
  static const String passport = '/passport';
  static const String profile = '/profile';
  static const String video = '/video';
  static const String submission = '/submission';
  static const String quiz = '/quiz';
  static const String error = '/error';

  static Page<void> _page(Widget child) => NoTransitionPage<void>(child: child);

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        pageBuilder: (context, state) => _page(const SplashScreen()),
      ),
      GoRoute(
        path: login,
        pageBuilder: (context, state) => _page(const AuthCheckScreen()),
      ),
      GoRoute(
        path: onboarding,
        pageBuilder: (context, state) => _page(const ConversationalOnboardingScreen()),
      ),
      GoRoute(
        path: profileSelect,
        pageBuilder: (context, state) => _page(
          ProfileSelectScreen(
            phone: state.uri.queryParameters['phone'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: home,
        pageBuilder: (context, state) => _page(const HomeScreen()),
      ),
      GoRoute(
        path: classroom,
        pageBuilder: (context, state) => _page(const ClassScreen()),
      ),
      GoRoute(
        path: passport,
        pageBuilder: (context, state) => _page(const PassportScreen()),
      ),
      GoRoute(
        path: profile,
        pageBuilder: (context, state) => _page(const SettingsScreen()),
      ),
      GoRoute(
        path: video,
        pageBuilder: (context, state) => _page(const VideoScreen()),
      ),
      GoRoute(
        path: submission,
        pageBuilder: (context, state) => _page(const SubmissionScreen()),
      ),
      GoRoute(
        path: quiz,
        pageBuilder: (context, state) => _page(const QuizScreen()),
      ),
      GoRoute(
        path: error,
        pageBuilder: (context, state) => _page(const ErrorScreen()),
      ),
    ],
  );
}
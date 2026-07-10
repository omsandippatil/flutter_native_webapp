import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/error/error_screen.dart';
import '../../screens/auth/auth_check_screen.dart';
import '../../screens/onboarding/welcome_back_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/class/class_screen.dart';
import '../../screens/passport/passport_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/video/video_screen.dart';
import '../../screens/submission/submission_screen.dart';
import '../../screens/quiz/quiz_screen.dart';
import '../../screens/public/events/events_screen.dart';
import '../../screens/public/events/events_detail_screen.dart';
import '../../screens/public/knowledge-centre/knowledge_centre_screen.dart';
import '../../screens/public/knowledge-centre/knowledge_centre_detail_screen.dart';
import '../../screens/public/projects/project_screen.dart';
import '../../screens/public/projects/project_detail_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String welcomeBack = '/welcome-back';
  static const String home = '/home';
  static const String classroom = '/classroom';
  static const String passport = '/passport';
  static const String profile = '/profile';
  static const String video = '/video';
  static const String submission = '/submission';
  static const String quiz = '/quiz';
  static const String error = '/error';

  // Public resources
  static const String events = '/events';
  static const String eventsDetail = '/events/:id';
  static const String knowledge = '/knowledge-centre';
  static const String knowledgeDetail = '/knowledge-centre/:id';
  static const String projects = '/projects';
  static const String projectsDetail = '/projects/:id';

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
        path: welcomeBack,
        pageBuilder: (context, state) => _page(
          WelcomeBackScreen(
            studentName: state.uri.queryParameters['name'] ?? 'Aarav',
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
      GoRoute(
        path: events,
        pageBuilder: (context, state) => _page(const EventsScreen()),
      ),
      GoRoute(
        path: eventsDetail,
        pageBuilder: (context, state) =>
            _page(EventsDetailScreen(id: state.pathParameters['id'] ?? 'e1')),
      ),
      GoRoute(
        path: knowledge,
        pageBuilder: (context, state) => _page(const KnowledgeCentreScreen()),
      ),
      GoRoute(
        path: knowledgeDetail,
        pageBuilder: (context, state) => _page(
          KnowledgeCentreDetailScreen(id: state.pathParameters['id'] ?? 'g1'),
        ),
      ),
      GoRoute(
        path: projects,
        pageBuilder: (context, state) => _page(const ProjectScreen()),
      ),
      GoRoute(
        path: projectsDetail,
        pageBuilder: (context, state) =>
            _page(ProjectDetailScreen(id: state.pathParameters['id'] ?? 'p1')),
      ),
    ],
  );
}

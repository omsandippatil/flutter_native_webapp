import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/router.dart';
import '../../widgets/error_view.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorView(
      // Mobile text configuration (from top mockup)
      title: 'Something went wrong',
      message:
          'We had trouble loading this page. Please check your internet connection and try again.',
      buttonText: 'Try Again',

      // Desktop/Web text configuration (from bottom mockup)
      desktopTitle: 'Hey Champ\nI am not able to talk to you',
      desktopMessage: "Looks like you're offline. Click below to try again.",
      desktopButtonText: 'Retry',

      onRetry: () {
        // Navigate back to splash screen to simulate reloading
        context.go(AppRoutes.splash);
      },
    );
  }
}

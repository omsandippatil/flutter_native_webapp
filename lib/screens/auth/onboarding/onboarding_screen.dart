import 'package:flutter/widgets.dart';

import 'controller/onboarding_runtime.dart';

/// Route entry point for the JSON-driven conversational onboarding feature.
///
/// Flow state and persistence live in the runtime/controller layer; reusable
/// presentation is in `widgets/`. Keep this file intentionally thin so app
/// routing never depends on implementation details of a specific flow.
class ConversationalOnboardingScreen extends StatelessWidget {
  const ConversationalOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingRuntime();
}

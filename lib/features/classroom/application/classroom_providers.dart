import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/features/classroom/application/activity_flow_provider.dart';
import 'package:tapapp/features/classroom/application/classroom_session_controller.dart';
import 'package:tapapp/features/classroom/application/classroom_bootstrap_provider.dart';
import 'package:tapapp/features/home/providers/home_dashboard_provider.dart';
import 'package:tapapp/core/localization/language_provider.dart';
import 'package:tapapp/domain/learner/providers/learner_state_providers.dart';
import 'package:tapapp/features/classroom/application/submission_review_provider.dart';

class NoUnitAvailableException implements Exception {
  const NoUnitAvailableException();

  @override
  String toString() => 'No unit is available to run right now.';
}

final classChatControllerProvider = FutureProvider.autoDispose
    .family<ClassChatController, int>((ref, attempt) async {
      final bootstrap = await ref.watch(classSessionBootstrapProvider.future);
      if (bootstrap.unit == null) {
        throw const NoUnitAvailableException();
      }

      final languageCode = ref.watch(languageProvider);
      final flow = await ref.watch(activityFlowProvider(languageCode).future);

      final learnerStateRepository = await ref.watch(
        learnerStateRepositoryProvider.future,
      );
      final submissionReviewRepository = await ref.watch(
        submissionReviewRepositoryProvider.future,
      );
      final sessionWindowRepository = await ref.watch(
        classSessionWindowRepositoryProvider.future,
      );
      final studentName =
          bootstrap.learnerState.profile?.studentName ?? 'Champ';
      var providerIsActive = true;

      final controller = ClassChatController(
        learnerId: bootstrap.learnerId,
        phone: bootstrap.phone,
        studentName: studentName,
        courseDisplay: bootstrap.courseName,
        flow: flow,
        unit: bootstrap.unit!,
        nextUnit: bootstrap.nextUnit,
        unitIndex: bootstrap.unitIndex,
        initialLearnerState: bootstrap.learnerState,
        learnerStateRepository: learnerStateRepository,
        submissionReviewRepository: submissionReviewRepository,
        sessionWindowRepository: sessionWindowRepository,
        onProgressSaved: () {
          if (!providerIsActive) return;
          ref.invalidate(learnerStateDataProvider(bootstrap.learnerId));
          ref.invalidate(learningDashboardProvider);
        },
      );

      ref.onDispose(() {
        providerIsActive = false;
        controller.dispose();
      });
      return controller;
    });

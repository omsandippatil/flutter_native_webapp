import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_models.dart';
import '../services/activity_service.dart';

final activityServiceProvider = Provider<ActivityService>((ref) {
  return const ActivityService();
});

class DashboardNotifier extends Notifier<AsyncValue<LearningDashboard>> {
  @override
  AsyncValue<LearningDashboard> build() {
    // Trigger initial loading
    Future.microtask(() => load());
    return const AsyncLoading();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final data = await ref.read(activityServiceProvider).loadDashboard();
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void completeVideo() {
    state.whenData((dashboard) {
      final progress = dashboard.progress;
      if (progress.watchedVideosThisWeek >= 2) {
        // limit of 2 videos per week reached!
        return;
      }
      final newProgress = StudentLearningProgress(
        studentName: progress.studentName,
        points: progress.points + dashboard.unit.videoPoints,
        streakDay: progress.streakDay,
        skillGems: progress.skillGems,
        watchedVideosThisWeek: progress.watchedVideosThisWeek + 1,
        videoDone: true,
        submissionDone: progress.submissionDone,
        quizDone: progress.quizDone,
      );
      state = AsyncData(LearningDashboard(unit: dashboard.unit, progress: newProgress));
    });
  }

  void submitProject() {
    state.whenData((dashboard) {
      final progress = dashboard.progress;
      final newProgress = StudentLearningProgress(
        studentName: progress.studentName,
        points: progress.points + dashboard.unit.submissionPoints,
        streakDay: progress.streakDay,
        skillGems: progress.skillGems,
        watchedVideosThisWeek: progress.watchedVideosThisWeek,
        videoDone: progress.videoDone,
        submissionDone: true,
        quizDone: progress.quizDone,
      );
      state = AsyncData(LearningDashboard(unit: dashboard.unit, progress: newProgress));
    });
  }

  void completeQuiz() {
    state.whenData((dashboard) {
      final progress = dashboard.progress;
      final newProgress = StudentLearningProgress(
        studentName: progress.studentName,
        points: progress.points + 5, // quiz points
        streakDay: progress.streakDay + 1,
        skillGems: progress.skillGems + 1,
        watchedVideosThisWeek: progress.watchedVideosThisWeek,
        videoDone: progress.videoDone,
        submissionDone: progress.submissionDone,
        quizDone: true,
      );
      state = AsyncData(LearningDashboard(unit: dashboard.unit, progress: newProgress));
    });
  }

  void reset() {
    state.whenData((dashboard) {
      final progress = dashboard.progress;
      final newProgress = StudentLearningProgress(
        studentName: progress.studentName,
        points: 0,
        streakDay: 5,
        skillGems: 1,
        watchedVideosThisWeek: 0,
        videoDone: false,
        submissionDone: false,
        quizDone: false,
      );
      state = AsyncData(LearningDashboard(unit: dashboard.unit, progress: newProgress));
    });
  }
}

final learningDashboardProvider = NotifierProvider<DashboardNotifier, AsyncValue<LearningDashboard>>(() {
  return DashboardNotifier();
});

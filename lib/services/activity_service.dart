import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/activity_models.dart';
import 'activity_progress_store.dart';

class ActivityService {
  const ActivityService();

  Future<LearningDashboard> loadDashboard() async {
    final courseJson = await rootBundle.loadString(
      'assets/flows/en/course/science.json',
    );
    final course = jsonDecode(courseJson) as Map<String, dynamic>;
    final saved =
        await ActivityProgressStore().read() ?? const <String, dynamic>{};
    final videoDone = saved['video_done'] == true;
    final submissionDone = saved['submission_done'] == true;
    final quizDone = saved['quiz_done'] == true;
    final units = course['units'] as List<dynamic>? ?? const [];
    final savedUnitIndex = saved['unit_index'] as int? ?? 0;
    final unitIndex = units.isEmpty
        ? 0
        : savedUnitIndex.clamp(0, units.length - 1).toInt();
    final unitJson = units.isEmpty
        ? <String, dynamic>{}
        : units[unitIndex] as Map<String, dynamic>;
    final unit = CourseUnit.fromUnitJson(course, unitJson);
    final quizScore = saved['quiz_score'] as int? ?? 0;
    final points =
        3 +
        (videoDone ? unit.videoPoints : 0) +
        (submissionDone ? unit.submissionPoints : 0) +
        (quizDone ? quizScore : 0);

    return LearningDashboard(
      unit: unit,
      progress: StudentLearningProgress(
        studentName: 'Aarav',
        points: points,
        streakDay: 5,
        skillGems: 1,
        watchedVideosThisWeek: videoDone ? 1 : 0,
        videoDone: videoDone,
        submissionDone: submissionDone,
        quizDone: quizDone,
      ),
    );
  }
}

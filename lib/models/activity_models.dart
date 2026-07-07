enum LearningStage { startActivity, sendProject, quizPending, completed }

class CourseUnit {
  final String courseId;
  final String courseDisplay;
  final String unitId;
  final int unitIndex;
  final String unitName;
  final String videoDescription;
  final String videoUrl;
  final int videoPoints;
  final String submissionPrompt;
  final int submissionPoints;
  final int quizQuestionCount;

  const CourseUnit({
    required this.courseId,
    required this.courseDisplay,
    required this.unitId,
    required this.unitIndex,
    required this.unitName,
    required this.videoDescription,
    required this.videoUrl,
    required this.videoPoints,
    required this.submissionPrompt,
    required this.submissionPoints,
    required this.quizQuestionCount,
  });

  factory CourseUnit.fromCourseJson(Map<String, dynamic> json) {
    final units = json['units'] as List<dynamic>? ?? const [];
    final unit = units.isNotEmpty
        ? units.first as Map<String, dynamic>
        : <String, dynamic>{};
    return CourseUnit.fromUnitJson(json, unit);
  }

  factory CourseUnit.fromUnitJson(
    Map<String, dynamic> courseJson,
    Map<String, dynamic> unit,
  ) {
    final video = unit['video'] as Map<String, dynamic>? ?? const {};
    final submission = unit['submission'] as Map<String, dynamic>? ?? const {};
    final quiz = unit['quiz'] as Map<String, dynamic>? ?? const {};
    final questions = quiz['questions'] as List<dynamic>? ?? const [];

    return CourseUnit(
      courseId: courseJson['course_id'] as String? ?? 'science',
      courseDisplay: courseJson['course_display'] as String? ?? 'Basic',
      unitId: unit['unit_id'] as String? ?? 'science_u01',
      unitIndex: unit['unit_index'] as int? ?? 0,
      unitName: unit['unit_name'] as String? ?? 'Get Ready For ScratchJr',
      videoDescription: video['description'] as String? ?? 'why bottles matter',
      videoUrl: video['url'] as String? ?? '',
      videoPoints: video['points'] as int? ?? 10,
      submissionPrompt:
          submission['prompt'] as String? ??
          'Share a clear screenshot or video of your activity.',
      submissionPoints: submission['points'] as int? ?? 25,
      quizQuestionCount: questions.length,
    );
  }

  String get displayCourseName => 'Basic';

  String get displayUnitName {
    if (unitName == 'States of Matter') return 'Get Ready for ScratchJr';
    return unitName;
  }

  int get totalPoints => videoPoints + submissionPoints + 5;
}

class StudentLearningProgress {
  final String studentName;
  final int points;
  final int streakDay;
  final int skillGems;
  final int watchedVideosThisWeek;
  final bool videoDone;
  final bool submissionDone;
  final bool quizDone;

  const StudentLearningProgress({
    required this.studentName,
    required this.points,
    required this.streakDay,
    required this.skillGems,
    required this.watchedVideosThisWeek,
    required this.videoDone,
    required this.submissionDone,
    required this.quizDone,
  });

  LearningStage get currentStage {
    if (!videoDone) return LearningStage.startActivity;
    if (!submissionDone) return LearningStage.sendProject;
    if (!quizDone) return LearningStage.quizPending;
    return LearningStage.completed;
  }

  bool get canWatchMoreVideosThisWeek => watchedVideosThisWeek < 2;
}

class LearningDashboard {
  final CourseUnit unit;
  final StudentLearningProgress progress;

  const LearningDashboard({required this.unit, required this.progress});
}

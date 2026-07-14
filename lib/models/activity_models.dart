import '../models/program_content/course_detail_model.dart';

enum LearningStage { startActivity, sendProject, quizPending, completed }

class CourseUnit {
  const CourseUnit({
    required this.unitIndex,
    required this.courseDisplay,
    required this.unitName,
    required this.videoDescription,
    required this.videoPoints,
    required this.submissionPoints,
    required this.submissionPrompt,
    required this.totalPoints,
  });

  final int unitIndex;
  final String courseDisplay;
  final String unitName;
  final String videoDescription;
  final int videoPoints;
  final int submissionPoints;
  final String submissionPrompt;
  final int totalPoints;

  factory CourseUnit.fromCourse(CourseDetailModel course, int unitIndex) {
    final unit = course.units[unitIndex];
    final video = unit.videos.isNotEmpty ? unit.videos.first : null;
    final assignment = unit.assignments.isNotEmpty ? unit.assignments.first : null;
    final assignmentStep = assignment != null && assignment.steps.isNotEmpty
        ? assignment.steps.first
        : null;

    return CourseUnit(
      unitIndex: unitIndex,
      courseDisplay: course.vertical.isNotEmpty ? course.vertical : course.name,
      unitName: unit.name,
      videoDescription: video?.description ?? unit.description,
      videoPoints: video?.points ?? unit.xp,
      submissionPoints: unit.xp,
      submissionPrompt: assignmentStep?.unguidedText ?? assignment?.description ?? '',
      totalPoints: unit.xp,
    );
  }
}

class LearningProgress {
  const LearningProgress({
    required this.studentName,
    required this.points,
    required this.skillGems,
    required this.streakDay,
    required this.videoDone,
    required this.submissionDone,
    required this.quizDone,
    required this.watchedVideosThisWeek,
  });

  final String studentName;
  final int points;
  final int skillGems;
  final int streakDay;
  final bool videoDone;
  final bool submissionDone;
  final bool quizDone;
  final int watchedVideosThisWeek;

  LearningStage get currentStage {
    if (!videoDone) return LearningStage.startActivity;
    if (!submissionDone) return LearningStage.sendProject;
    if (!quizDone) return LearningStage.quizPending;
    return LearningStage.completed;
  }
}

class LearningDashboard {
  const LearningDashboard({
    required this.progress,
    required this.unit,
    required this.hasEnrollment,
    required this.hasReachedWeeklyCap,
  });

  final LearningProgress progress;
  final CourseUnit? unit;
  final bool hasEnrollment;
  final bool hasReachedWeeklyCap;
}
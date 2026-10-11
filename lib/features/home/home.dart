import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapapp/core/course/course.dart';
import 'package:tapapp/core/learner/learner.dart';
import 'package:tapapp/core/profile/profile.dart';
import 'package:tapapp/features/classroom/classroom.dart';

enum LearningStage { startActivity, sendProject, quizPending, completed }

extension LearningStageClassroomMapper on ClassroomProgressStage {
  LearningStage get homeStage => switch (this) {
    ClassroomProgressStage.watchVideo => LearningStage.startActivity,
    ClassroomProgressStage.submitProject => LearningStage.sendProject,
    ClassroomProgressStage.takeQuiz => LearningStage.quizPending,
    ClassroomProgressStage.unitCompleted => LearningStage.completed,
  };
}

class CourseUnit {
  const CourseUnit({
    required this.courseDisplay,
    required this.unitName,
    required this.thumbnailAsset,
    required this.videoPoints,
    required this.submissionPoints,
    required this.totalPoints,
  });

  final String courseDisplay;
  final String unitName;
  final String thumbnailAsset;
  final int videoPoints;
  final int submissionPoints;
  final int totalPoints;

  factory CourseUnit.fromCourse(CourseDetailModel course, int unitIndex) {
    final unit = course.units[unitIndex];
    final video = unit.videos.isNotEmpty ? unit.videos.first : null;
    return CourseUnit(
      courseDisplay: course.vertical.isNotEmpty ? course.vertical : course.name,
      unitName: unit.name,
      thumbnailAsset: 'assets/data/courses/thumbnail/${course.id}.webp',
      videoPoints: video?.points ?? unit.xp,
      submissionPoints: unit.xp,
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
    required this.classroomStage,
  });

  final String studentName;
  final int points;
  final int skillGems;
  final int streakDay;
  final bool videoDone;
  final bool submissionDone;
  final bool quizDone;
  final ClassroomProgressStage classroomStage;

  LearningStage get currentStage => classroomStage.homeStage;
}

class LearningDashboard {
  const LearningDashboard({
    required this.progress,
    required this.unit,
    required this.hasEnrollment,
    required this.hasReachedWeeklyCap,
    this.showCompletionCelebration = false,
    this.completionPoints = 0,
  });

  final LearningProgress progress;
  final CourseUnit? unit;
  final bool hasEnrollment;
  final bool hasReachedWeeklyCap;
  final bool showCompletionCelebration;
  final int completionPoints;
}

class NoEnrollmentException implements Exception {
  const NoEnrollmentException();

  @override
  String toString() => 'This profile has no active course enrollment.';
}

LearningProgress _buildProgress({
  required ActiveProfileModel profile,
  required LearnerStateModel learnerState,
  required EnrollmentModel enrollment,
  required int unitIndex,
  CourseUnitModel? unit,
}) {
  final snapshot = ClassroomProgressResolver.resolve(
    enrollment: enrollment,
    unitIndex: unitIndex,
    unit: unit,
  );

  return LearningProgress(
    studentName:
        learnerState.profile?.studentName ?? profile.studentName ?? 'Champ',
    points: learnerState.xp ?? 0,
    skillGems: learnerState.submissionGems ?? 0,
    streakDay: learnerState.streak ?? 0,
    videoDone: snapshot.videoDone,
    submissionDone: snapshot.submissionDone,
    quizDone: snapshot.quizDone,
    classroomStage: snapshot.stage,
  );
}

final learningDashboardProvider = FutureProvider.autoDispose<LearningDashboard>(
  (ref) async {
    final resolution = await ClassroomSessionResolver.resolve(ref);
    final enrollment = resolution.learnerState.enrollment;

    final profile = ActiveProfileModel(
      phone: resolution.phone,
      learnerId: resolution.learnerState.learnerId,
      studentName: resolution.learnerState.profile?.studentName,
    );

    if (enrollment == null || enrollment.course == null) {
      return LearningDashboard(
        progress: _buildProgress(
          profile: profile,
          learnerState: resolution.learnerState,
          enrollment: const EnrollmentModel(),
          unitIndex: 0,
        ),
        unit: null,
        hasEnrollment: false,
        hasReachedWeeklyCap: resolution.weeklyCapReached,
      );
    }

    final progress = _buildProgress(
      profile: profile,
      learnerState: resolution.learnerState,
      enrollment: enrollment,
      unitIndex: resolution.unitIndex,
      unit: resolution.unit,
    );

    return LearningDashboard(
      progress: progress,
      unit: resolution.unit == null
          ? null
          : CourseUnit.fromCourse(resolution.course!, resolution.unitIndex),
      hasEnrollment: true,
      hasReachedWeeklyCap: resolution.weeklyCapReached,
      showCompletionCelebration: resolution.showCompletionCelebration,
      completionPoints: resolution.completionPoints,
    );
  },
);

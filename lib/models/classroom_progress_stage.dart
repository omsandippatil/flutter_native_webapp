import 'enrollment_model.dart';
import 'program_content/course_detail_model.dart';

enum ClassroomProgressStage {
  watchVideo,
  submitProject,
  takeQuiz,
  unitCompleted;

  bool get isVideoDone => switch (this) {
    ClassroomProgressStage.watchVideo => false,
    _ => true,
  };

  bool get isSubmissionDone => switch (this) {
    ClassroomProgressStage.watchVideo ||
    ClassroomProgressStage.submitProject => false,
    _ => true,
  };

  bool get isQuizDone => this == ClassroomProgressStage.unitCompleted;

  double get revealProgress => switch (this) {
    ClassroomProgressStage.watchVideo => 0,
    ClassroomProgressStage.submitProject => 0.34,
    ClassroomProgressStage.takeQuiz => 0.67,
    ClassroomProgressStage.unitCompleted => 1,
  };
}

class ClassroomProgressSnapshot {
  const ClassroomProgressSnapshot({
    required this.stage,
    required this.unitIndex,
    required this.videoDone,
    required this.submissionDone,
    required this.quizDone,
  });

  final ClassroomProgressStage stage;
  final int unitIndex;
  final bool videoDone;
  final bool submissionDone;
  final bool quizDone;

  double get revealProgress => stage.revealProgress;
}

class ClassroomProgressResolver {
  const ClassroomProgressResolver._();

  static int resolveUnitIndex(EnrollmentModel enrollment, int totalUnits) {
    final firstIncomplete = [
      enrollment.videosCompleted,
      enrollment.quizzesCompleted,
      enrollment.submissionIndex,
    ].reduce((a, b) => a < b ? a : b);
    if (totalUnits == 0) return 0;
    return firstIncomplete >= totalUnits ? totalUnits - 1 : firstIncomplete;
  }

  static int resolveUnitIndexForCourse(
    EnrollmentModel enrollment,
    List<CourseUnitModel> units,
  ) {
    if (units.isEmpty) return 0;
    for (var index = 0; index < units.length; index++) {
      final snapshot = resolve(
        enrollment: enrollment,
        unitIndex: index,
        unit: units[index],
      );
      if (snapshot.stage != ClassroomProgressStage.unitCompleted) {
        return index;
      }
    }
    return units.length - 1;
  }

  static ClassroomProgressSnapshot resolve({
    required EnrollmentModel enrollment,
    required int unitIndex,
    CourseUnitModel? unit,
  }) {
    final videoDone = enrollment.videosCompleted > unitIndex;
    final submissionDone = enrollment.submissionIndex > unitIndex;
    final quizDone = enrollment.quizzesCompleted > unitIndex;
    final hasSubmission = unit == null || unit.assignments.isNotEmpty;
    final hasQuiz = unit == null || (unit.quiz?.questions.isNotEmpty ?? true);

    final stage = !videoDone
        ? ClassroomProgressStage.watchVideo
        : hasSubmission && !submissionDone
        ? ClassroomProgressStage.submitProject
        : hasQuiz && !quizDone
        ? ClassroomProgressStage.takeQuiz
        : ClassroomProgressStage.unitCompleted;

    return ClassroomProgressSnapshot(
      stage: stage,
      unitIndex: unitIndex,
      videoDone: videoDone,
      submissionDone: !hasSubmission || submissionDone,
      quizDone: !hasQuiz || quizDone,
    );
  }
}

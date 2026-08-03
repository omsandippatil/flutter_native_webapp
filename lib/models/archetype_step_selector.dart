import 'learner_archetype.dart';
import 'program_content/course_detail_model.dart';

class ArchetypeStepSelector {
  ArchetypeStepSelector._();

  static CourseAssignmentModel? selectAssignment(
    List<CourseAssignmentModel> assignments,
    String archetype,
  ) {
    if (assignments.isEmpty) return null;

    final normalized = LearnerArchetype.normalize(archetype);
    for (final assignment in assignments) {
      if (assignment.id.toLowerCase().contains(normalized)) {
        return assignment;
      }
    }
    return assignments.first;
  }

  static CourseAssignmentStepModel? selectStep(
    List<CourseAssignmentStepModel> steps,
    String archetype,
  ) {
    if (steps.isEmpty) return null;

    final normalized = LearnerArchetype.normalize(archetype);
    for (final step in steps) {
      if (step.label.toLowerCase().contains(normalized)) {
        return step;
      }
    }
    return steps.first;
  }
}

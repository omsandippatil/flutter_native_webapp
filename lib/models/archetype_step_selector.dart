import 'learner_archetype.dart';
import 'program_content/course_detail_model.dart';

/// Picks which assignment (and which step within it) to show a learner,
/// based on their current archetype level.
///
/// Course JSON may optionally tag an assignment's `id` or a step's `label`
/// with an archetype suffix, e.g. an id like
/// "Build-Your-First-Animation-🐱-Basic" already carries a difficulty tag;
/// archetype tagging follows the same convention by looking for the
/// archetype name inside the id/label (case-insensitive). If no
/// archetype-specific variant exists, this falls back to the first
/// assignment/step — so content that hasn't been authored with
/// per-archetype variants yet keeps working exactly as before.
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
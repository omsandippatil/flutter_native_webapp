import 'learner_archetype.dart';
import 'submission_answer_model.dart';

class ArchetypeSubmissionKind {
  ArchetypeSubmissionKind._();

  static SubmissionKind forArchetype(String? archetype) {
    final normalized = LearnerArchetype.normalize(archetype);
    switch (normalized) {
      case LearnerArchetype.dormant:
        return SubmissionKind.emoji;
      case LearnerArchetype.fenceSitter:
        return SubmissionKind.text;
      case LearnerArchetype.irregularSubmitter:
        return SubmissionKind.image;
      case LearnerArchetype.submitter:
        return SubmissionKind.textAudio;
      default:
        return SubmissionKind.emoji;
    }
  }
}
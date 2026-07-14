/// Mirrors the backend's Python constants exactly:
///
/// ARCHETYPE_DORMANT = "dormant"
/// ARCHETYPE_FENCE_SITTER = "fence_sitter"
/// ARCHETYPE_IRREGULAR_SUBMITTER = "irregular_submitter"
/// ARCHETYPE_SUBMITTER = "submitter"
class LearnerArchetype {
  LearnerArchetype._();

  static const String dormant = 'dormant';
  static const String fenceSitter = 'fence_sitter';
  static const String irregularSubmitter = 'irregular_submitter';
  static const String submitter = 'submitter';

  /// Ordered ladder, lowest engagement first. Index in this list is the
  /// "level" used by [next] and by content lookups in
  /// [CourseAssignmentStepModel]-style archetype-tagged variants.
  static const List<String> ladder = [dormant, fenceSitter, irregularSubmitter, submitter];

  static bool isValid(String value) => ladder.contains(value);

  static int levelOf(String? value) {
    if (value == null) return 0;
    final idx = ladder.indexOf(value);
    return idx == -1 ? 0 : idx;
  }

  /// Every accepted submission bumps the learner one level up the ladder,
  /// capping at [submitter]. Never demotes.
  static String next(String? current) {
    final level = levelOf(current);
    final nextLevel = (level + 1).clamp(0, ladder.length - 1);
    return ladder[nextLevel];
  }

  static String normalize(String? value) => isValid(value ?? '') ? value! : dormant;
}
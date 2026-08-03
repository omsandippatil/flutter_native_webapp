
class LearnerArchetype {
  LearnerArchetype._();

  static const String dormant = 'dormant';
  static const String fenceSitter = 'fence_sitter';
  static const String irregularSubmitter = 'irregular_submitter';
  static const String submitter = 'submitter';

  static const List<String> ladder = [
    dormant,
    fenceSitter,
    irregularSubmitter,
    submitter,
  ];

  static bool isValid(String value) => ladder.contains(value);

  static int levelOf(String? value) {
    if (value == null) return 0;
    final idx = ladder.indexOf(value);
    return idx == -1 ? 0 : idx;
  }

  static String next(String? current) {
    final level = levelOf(current);
    final nextLevel = (level + 1).clamp(0, ladder.length - 1);
    return ladder[nextLevel];
  }

  static String normalize(String? value) =>
      isValid(value ?? '') ? value! : dormant;
}

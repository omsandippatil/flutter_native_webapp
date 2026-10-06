import 'package:tapapp/domain/learner/models/learner_archetype.dart';

class LocalArchetypeCalculator {
  LocalArchetypeCalculator._();

  static String compute({
    required int streak,
    required int submissionCount,
    required String? lastActivityDate,
    required DateTime now,
  }) {
    final daysSinceLastActivity = _daysSince(lastActivityDate, now);
    if (daysSinceLastActivity == null || daysSinceLastActivity > 21) {
      return LearnerArchetype.dormant;
    }
    if (submissionCount <= 0) {
      return LearnerArchetype.fenceSitter;
    }
    if (streak < 2) {
      return LearnerArchetype.irregularSubmitter;
    }
    return LearnerArchetype.submitter;
  }

  static int? _daysSince(String? isoDate, DateTime now) {
    if (isoDate == null) return null;
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return null;
    return now.difference(parsed).inDays;
  }
}

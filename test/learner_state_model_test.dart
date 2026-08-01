import 'package:flutter_test/flutter_test.dart';
import 'package:tapapp/models/learner_state_model.dart';

void main() {
  test('parses weekly activity field names returned by the backend', () {
    final state = LearnerStateModel.fromFullJson('learner-1', {
      'activities_watched_this_week': 2,
      'max_weekly_activities': 2,
      'activities_remaining': 0,
      'is_bingeing': true,
    });

    expect(state.unitsCompletedThisWeek, 2);
    expect(state.maxWeeklyUnits, 2);
    expect(state.unitsRemaining, 0);
    expect(state.isBingeing, isTrue);
  });
}

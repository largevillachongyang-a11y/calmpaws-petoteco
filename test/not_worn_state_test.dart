import 'package:flutter_test/flutter_test.dart';
import 'package:petoteco/models/models.dart';
import 'package:petoteco/theme/state_colors.dart';

void main() {
  test('maps server no-wear labels to notWorn behavior', () {
    expect(
      StateColors.behaviorFromLabel('not_worn'),
      PetBehaviorState.notWorn,
    );
    expect(
      StateColors.behaviorFromLabel('notWorn'),
      PetBehaviorState.notWorn,
    );
  });

  test('notWorn has user-facing labels', () {
    expect(PetBehaviorState.notWorn.label, 'Not worn');
    expect(PetBehaviorState.notWorn.labelZh, '未佩戴');
    expect(StateColors.labelFor('not_worn', true), '未佩戴');
    expect(StateColors.labelFor('not_worn', false), 'Not worn');
  });
}

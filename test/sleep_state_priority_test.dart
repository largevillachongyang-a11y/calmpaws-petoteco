import 'package:flutter_test/flutter_test.dart';
import 'package:petoteco/models/models.dart';
import 'package:petoteco/providers/pet_health_provider.dart';

void main() {
  test('sleep abnormal and not-worn states override normal behavior labels',
      () {
    expect(
      PetHealthProvider.resolveBehaviorForDisplay(
        PetBehaviorState.playing,
        PetBehaviorState.sleepAbnormal,
      ),
      PetBehaviorState.sleepAbnormal,
    );

    expect(
      PetHealthProvider.resolveBehaviorForDisplay(
        PetBehaviorState.stressed,
        PetBehaviorState.notWorn,
      ),
      PetBehaviorState.notWorn,
    );
  });

  test('sleep normal only overrides calm behavior', () {
    expect(
      PetHealthProvider.resolveBehaviorForDisplay(
        PetBehaviorState.calm,
        PetBehaviorState.sleepNormal,
      ),
      PetBehaviorState.sleepNormal,
    );

    expect(
      PetHealthProvider.resolveBehaviorForDisplay(
        PetBehaviorState.playing,
        PetBehaviorState.sleepNormal,
      ),
      PetBehaviorState.playing,
    );
  });
}

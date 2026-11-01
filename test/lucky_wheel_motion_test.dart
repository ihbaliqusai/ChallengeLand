import 'dart:math' as math;

import 'package:challenge_land/core/lucky_wheel_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LuckyWheelSpinCurve', () {
    const curve = LuckyWheelSpinCurve();
    double velocity(double time) {
      const delta = .00001;
      return (curve.transform(time + delta) - curve.transform(time - delta)) /
          (2 * delta);
    }

    test('preserves exact endpoints and monotonic forward motion', () {
      expect(luckyWheelSpinDuration, const Duration(milliseconds: 4800));
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      var previous = 0.0;
      for (var sample = 1; sample <= 1000; sample++) {
        final current = curve.transform(sample / 1000);
        expect(current, inInclusiveRange(previous, 1.0));
        previous = current;
      }
    });

    test('accelerates, coasts briefly, and loses speed progressively', () {
      expect(velocity(.025), lessThan(velocity(.05)));
      expect(velocity(.05), lessThan(velocity(.075)));
      expect(velocity(.13), closeTo(velocity(.19), .00001));
      expect(velocity(.3), greaterThan(velocity(.5)));
      expect(velocity(.5), greaterThan(velocity(.7)));
      expect(velocity(.7), greaterThan(velocity(.9)));
      expect(velocity(.999), lessThan(.0001));
      expect(velocity(.001), lessThan(.001));
    });

    test('has continuous distance and speed at the phase boundaries', () {
      for (final boundary in [.10, .22]) {
        expect(curve.transform(boundary - .000001),
            closeTo(curve.transform(boundary + .000001), .00001));
        expect(velocity(boundary - .0001),
            closeTo(velocity(boundary + .0001), .002));
      }
    });
  });

  group('LuckyWheelPointerSpring', () {
    test('does not manufacture an impact when primed or idle', () {
      final pointer = LuckyWheelPointerSpring();
      pointer.step(elapsedSeconds: 0, turns: 1 / 24, turnsPerSecond: 0);
      for (var frame = 0; frame < 180; frame++) {
        pointer.step(elapsedSeconds: 1 / 60, turns: 1 / 24, turnsPerSecond: 0);
      }
      expect(pointer.angle, 0);
      expect(pointer.angularVelocity, 0);
    });

    test('first boundary peg pushes the needle counterclockwise', () {
      final pointer = LuckyWheelPointerSpring();
      pointer.step(elapsedSeconds: 0, turns: 0, turnsPerSecond: 0);
      pointer.step(
          elapsedSeconds: .1, turns: 1 / 24 - .001, turnsPerSecond: .4);
      expect(pointer.angle, 0);
      expect(pointer.angularVelocity, 0);
      pointer.step(
          elapsedSeconds: 1 / 60, turns: 1 / 24 + .002, turnsPerSecond: .18);
      expect(pointer.angle, lessThan(0));
      expect(pointer.angularVelocity, lessThan(0));
    });

    test('releases, rebounds once clear of the peg, and settles at rest', () {
      final pointer = LuckyWheelPointerSpring();
      pointer.step(elapsedSeconds: 0, turns: 0, turnsPerSecond: 0);
      var turns = 0.0;
      var minimumAngle = 0.0;
      for (var frame = 0; frame < 46; frame++) {
        turns += .08 / 60;
        pointer.step(elapsedSeconds: 1 / 60, turns: turns, turnsPerSecond: .08);
        minimumAngle = math.min(minimumAngle, pointer.angle);
      }
      expect(minimumAngle, lessThan(-.05));
      var rebound = 0.0;
      for (var frame = 0; frame < 180; frame++) {
        pointer.step(elapsedSeconds: 1 / 60, turns: turns, turnsPerSecond: 0);
        rebound = math.max(rebound, pointer.angle);
      }
      expect(rebound, greaterThan(.001));
      expect(pointer.angle, 0);
      expect(pointer.angularVelocity, 0);
    });

    test('swept fast contacts and long frames remain finite and bounded', () {
      final pointer = LuckyWheelPointerSpring();
      pointer.step(elapsedSeconds: 0, turns: 0, turnsPerSecond: 0);
      var turns = 0.0;
      var deflection = 0.0;
      for (var frame = 0; frame < 60; frame++) {
        turns += 4 / 30;
        pointer.step(elapsedSeconds: 1 / 30, turns: turns, turnsPerSecond: 4);
        deflection = math.min(deflection, pointer.angle);
        expect(pointer.angle, inInclusiveRange(-.5, .14));
        expect(pointer.angularVelocity.isFinite, isTrue);
      }
      expect(deflection, lessThan(-.02));
      pointer.step(elapsedSeconds: 4, turns: turns + 12, turnsPerSecond: .5);
      expect(pointer.angle.isFinite, isTrue);
      expect(pointer.angularVelocity.isFinite, isTrue);
      expect(pointer.angle, inInclusiveRange(-.5, .14));
      pointer.step(elapsedSeconds: 20, turns: turns + 12, turnsPerSecond: 0);
      expect(pointer.angle, 0);
      expect(pointer.angularVelocity, 0);
    });

    test('reset removes residual energy and reprimes without a false hit', () {
      final pointer = LuckyWheelPointerSpring();
      pointer.step(elapsedSeconds: 0, turns: 0, turnsPerSecond: 0);
      pointer.step(elapsedSeconds: .1, turns: .05, turnsPerSecond: .5);
      expect(pointer.angle, lessThan(0));
      pointer.reset();
      pointer.step(elapsedSeconds: 1 / 60, turns: 5.05, turnsPerSecond: 3);
      expect(pointer.angle, 0);
      expect(pointer.angularVelocity, 0);
    });
  });
}

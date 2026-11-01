import 'dart:math' as math;

import 'package:flutter/animation.dart';

const luckyWheelSpinDuration = Duration(milliseconds: 4800);

/// Distance integrated from a smooth launch, a short constant-speed section,
/// and a quadratic fall in speed under friction. The disc never reverses.
class LuckyWheelSpinCurve extends Curve {
  const LuckyWheelSpinCurve();

  static const _launchEnd = .10;
  static const _coastEnd = .22;
  static const _brakingLength = 1 - _coastEnd;
  static const _launchDistance = _launchEnd / 2;
  static const _coastDistance = _coastEnd - _launchEnd;
  static const _distance =
      _launchDistance + _coastDistance + _brakingLength / 3;

  @override
  double transformInternal(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    if (t < _launchEnd) {
      final progress = t / _launchEnd;
      // Integral of smoothstep velocity, 3p² - 2p³.
      return _launchEnd *
          (progress * progress * progress -
              .5 * progress * progress * progress * progress) /
          _distance;
    }
    if (t < _coastEnd) {
      return (_launchDistance + t - _launchEnd) / _distance;
    }
    final remaining = (1 - t) / _brakingLength;
    return (_launchDistance +
            _coastDistance +
            _brakingLength * (1 - remaining * remaining * remaining) / 3) /
        _distance;
  }
}

/// A hinged needle pushed back by the twelve boundary pegs on the disc.
///
/// [step]'s elapsedSeconds is a frame delta. Prime after [reset] with the
/// initial absolute turn value and elapsedSeconds: 0. Turns remain cumulative
/// between frames; the first peg reaches the pointer at 1/24 turn. Positive
/// disc motion pushes the needle counterclockwise (a negative [angle]).
class LuckyWheelPointerSpring {
  static const _pegs = 12;
  static const _spring = 200.0;
  static const _damping = 14.0;
  static const _contactSpring = 650.0;
  static const _contactDamping = 18.0;
  static const _contactTravel = .22;
  static const _maximumStep = 1 / 120;
  static const _maximumCatchUp = 1.0;
  static const _minimumAngle = -.50;
  static const _maximumAngle = .14;

  double _angle = 0;
  double _angularVelocity = 0;
  double? _previousTurns;

  /// Needle deflection in radians; zero is the resting vertical position.
  double get angle => _angle;

  /// Needle velocity in radians per second.
  double get angularVelocity => _angularVelocity;

  void reset() {
    _angle = 0;
    _angularVelocity = 0;
    _previousTurns = null;
  }

  void step({
    required double elapsedSeconds,
    required double turns,
    required double turnsPerSecond,
  }) {
    if (!elapsedSeconds.isFinite ||
        !turns.isFinite ||
        !turnsPerSecond.isFinite) {
      return;
    }
    final previousTurns = _previousTurns;
    _previousTurns = turns;
    if (previousTurns == null || elapsedSeconds <= 0) return;

    final frameTurns = turns - previousTurns;
    final forward = frameTurns > 1e-10;
    final speed = math.max(0.0, turnsPerSecond);
    var duration = elapsedSeconds;
    var startTurns = previousTurns;
    if (duration > _maximumCatchUp) {
      // After a suspended frame, only the latest second of contacts can still
      // affect the visible needle. Decay older energy without an unbounded loop.
      _advanceFree(duration - _maximumCatchUp);
      startTurns = turns - frameTurns * _maximumCatchUp / duration;
      duration = _maximumCatchUp;
    }
    final steps = (duration / _maximumStep).ceil();
    final dt = duration / steps;
    final activeTurns = turns - startTurns;
    final measuredSpeed = forward ? activeTurns / duration : 0.0;
    final contactSpeed = math.max(speed, measuredSpeed);

    for (var index = 0; index < steps; index++) {
      final start = startTurns + activeTurns * index / steps;
      final end = startTurns + activeTurns * (index + 1) / steps;
      final startPhase = start * _pegs + .5;
      final endPhase = end * _pegs + .5;
      var force = -_spring * _angle - _damping * _angularVelocity;

      if (forward) {
        final hits = endPhase.floor() - startPhase.floor();
        if (hits > 0) {
          // Swept peg crossings cannot disappear between sampled frames.
          final impact = math.min(1.1, .25 + .4 * math.sqrt(contactSpeed));
          _angularVelocity -= impact * math.min(hits, 2);
        }
        final travel = endPhase - endPhase.floorToDouble();
        if (travel < _contactTravel) {
          final progress = travel / _contactTravel;
          final pegAngle = -.08 - .36 * math.sin(progress * math.pi / 2);
          final penetration = _angle - pegAngle;
          if (penetration > 0) {
            // A peg may push the needle, but cannot pull it back after release.
            force -= _contactSpring * penetration +
                _contactDamping * math.max(0.0, _angularVelocity);
          }
        }
      }

      _angularVelocity += force * dt;
      _angle += _angularVelocity * dt;
      _boundNeedle();
    }
    _settle();
  }

  void _boundNeedle() {
    if (_angle < _minimumAngle) {
      _angle = _minimumAngle;
      if (_angularVelocity < 0) _angularVelocity = 0;
    } else if (_angle > _maximumAngle) {
      _angle = _maximumAngle;
      if (_angularVelocity > 0) _angularVelocity = 0;
    }
  }

  void _advanceFree(double seconds) {
    // Exact underdamped solution for the spring when no visible frame exists.
    const decay = _damping / 2;
    final frequency = math.sqrt(_spring - decay * decay);
    final attenuation = math.exp(-decay * seconds);
    final cosine = math.cos(frequency * seconds);
    final sine = math.sin(frequency * seconds);
    final oldAngle = _angle;
    final oldVelocity = _angularVelocity;
    _angle = attenuation *
        (oldAngle * cosine +
            (oldVelocity + decay * oldAngle) / frequency * sine);
    _angularVelocity = attenuation *
        (oldVelocity * cosine -
            (decay * oldVelocity + _spring * oldAngle) / frequency * sine);
    _boundNeedle();
  }

  void _settle() {
    if (_angle.abs() < .0001 && _angularVelocity.abs() < .002) {
      _angle = 0;
      _angularVelocity = 0;
    }
  }
}

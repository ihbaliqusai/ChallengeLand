import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original mode artwork with native, accessible controls for each game mode.
class GameModesArtwork extends StatelessWidget {
  const GameModesArtwork({
    super.key,
    required this.isOnline,
    required this.onClose,
    required this.onMainChallenge,
    required this.onGroupChallenge,
    required this.onFriendChallenge,
    required this.onOffline,
    required this.onUnavailable,
  });

  static const asset = 'assets/ui/game_modes.webp';
  static const _frame = Rect.fromLTRB(.032, .046, .968, .955);
  static const aspectRatio = (2400 * .936) / (1792 * .909);
  final bool isOnline;
  final VoidCallback onClose;
  final VoidCallback onMainChallenge;
  final VoidCallback onGroupChallenge;
  final VoidCallback onFriendChallenge;
  final VoidCallback onOffline;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: RepaintBoundary(
          key: const ValueKey('game-modes-artwork'),
          child: AspectRatio(
              aspectRatio: aspectRatio,
              child: LayoutBuilder(builder: (context, area) {
                Rect map(Rect rect) => Rect.fromLTRB(
                    (rect.left - _frame.left) / _frame.width * area.maxWidth,
                    (rect.top - _frame.top) / _frame.height * area.maxHeight,
                    (rect.right - _frame.left) / _frame.width * area.maxWidth,
                    (rect.bottom - _frame.top) /
                        _frame.height *
                        area.maxHeight);
                Widget action(Rect region, String title, VoidCallback onTap,
                    {String? hint, bool enabled = true}) {
                  final bounds = map(region);
                  final radius = bounds.shortestSide * .12;
                  return Positioned.fromRect(
                      rect: Rect.fromCenter(
                          center: bounds.center,
                          width: math.max(48, bounds.width),
                          height: math.max(48, bounds.height)),
                      child: Tooltip(
                          message: title,
                          child: Semantics(
                              label: title,
                              hint: hint,
                              button: true,
                              enabled: enabled,
                              child: ExcludeSemantics(
                                  child: Stack(children: [
                                if (!enabled)
                                  Positioned.fill(
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: .4),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      radius)))),
                                Positioned.fill(
                                    child: TextButton(
                                        onPressed:
                                            enabled ? onTap : onUnavailable,
                                        style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        radius))),
                                        child: const SizedBox.expand())),
                                if (!enabled)
                                  Positioned(
                                      top: 7,
                                      left: 7,
                                      child: Icon(Icons.lock_rounded,
                                          size: (area.maxHeight * .065)
                                              .clamp(14.0, 24.0),
                                          color: Colors.white70)),
                              ])))));
                }

                return Semantics(
                    namesRoute: true,
                    label: 'أوضاع اللعب',
                    child: Stack(children: [
                      Positioned.fill(
                          child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(area.maxWidth * .035),
                              child: ClipRect(
                                  child: Stack(children: [
                                Positioned(
                                    left: -_frame.left /
                                        _frame.width *
                                        area.maxWidth,
                                    top: -_frame.top /
                                        _frame.height *
                                        area.maxHeight,
                                    width: area.maxWidth / _frame.width,
                                    height: area.maxHeight / _frame.height,
                                    child: Image.asset(asset,
                                        fit: BoxFit.fill,
                                        excludeFromSemantics: true)),
                              ])))),
                      action(const Rect.fromLTRB(.077, .098, .166, .218),
                          'إغلاق', onClose),
                      action(const Rect.fromLTRB(.076, .257, .923, .552),
                          'التحدي الرئيسي', onMainChallenge,
                          hint: 'فريقان على جهاز واحد'),
                      action(const Rect.fromLTRB(.657, .590, .924, .900),
                          'تحدي جماعي', onGroupChallenge,
                          hint: 'غرف ومنافسة أونلاين', enabled: isOnline),
                      action(const Rect.fromLTRB(.368, .590, .635, .900),
                          'تحدي صديق', onFriendChallenge,
                          hint: '1 ضد 1 أو منافس عشوائي', enabled: isOnline),
                      action(const Rect.fromLTRB(.076, .590, .345, .900),
                          'أوفلاين', onOffline,
                          hint: 'العب بدون اتصال'),
                    ]));
              }))));
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

export 'game_store_navigation.dart';

const storeNavy = Color(0xFF100B36);
const storePink = Color(0xFFFF259F);
const storeGold = Color(0xFFFFD52A);

/// Beveled, glossy surfaces shared by the shop's cards and navigation.
class GameStoreFrame extends StatelessWidget {
  const GameStoreFrame({
    super.key,
    required this.child,
    this.colors = const [Color(0xFFAB00F5), Color(0xFFC238F7)],
    this.radius = 9,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final List<Color> colors;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          border: Border.all(color: const Color(0xFFE4B8FF), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFF03001A), offset: Offset(0, 4)),
          ],
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius - 1),
            border: Border.all(color: const Color(0xFF6E139A), width: 2),
          ),
          child: child,
        ),
      );
}

class GameStoreText extends StatelessWidget {
  const GameStoreText(this.text,
      {super.key,
      this.size = 22,
      this.color = Colors.white,
      this.maxLines = 1});
  final String text;
  final double size;
  final Color color;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1.3,
          shadows: const [
            Shadow(
                color: Color(0xFF241332), offset: Offset(0, 2), blurRadius: 2),
            Shadow(
                color: Color(0xFF241332), offset: Offset(1, 0), blurRadius: 1),
          ],
        ),
      );
}

/// Keep the supplied membership artwork, including its original glossy button
/// and padlock. Only the printed label is replaced with native billing UI.
class GameStoreMembershipCard extends StatelessWidget {
  const GameStoreMembershipCard({super.key, required this.priceButton});
  final Widget priceButton;
  static const asset = 'assets/store/membership.webp';

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 3168 / 1344,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final label = Rect.fromLTRB(
              width * .119, height * .584, width * .389, height * .688);
          // This clean green strip is beside the printed label at the same height.
          // Stretching it across the lettering keeps the original bevel and glint.
          const strip = Rect.fromLTRB(.393, .584, .406, .688);
          return Stack(children: [
            Positioned.fill(
                child: Image.asset(asset,
                    key: const ValueKey('store-membership-art'),
                    fit: BoxFit.contain,
                    excludeFromSemantics: true)),
            Positioned.fromRect(
                rect: label,
                child: ClipRect(
                    child: Stack(children: [
                  Positioned(
                      left: -strip.left / strip.width * label.width,
                      top: -strip.top / strip.height * label.height,
                      width: label.width / strip.width,
                      height: label.height / strip.height,
                      child: Image.asset(asset,
                          fit: BoxFit.fill, excludeFromSemantics: true)),
                ]))),
            Positioned.fromRect(
                rect: Rect.fromLTRB(
                    width * .054, height * .536, width * .447, height * .739),
                child: SizedBox(
                    key: const ValueKey('store-membership-action'),
                    child: priceButton)),
          ]);
        }),
      );
}

class GameStoreMembershipPrice extends StatelessWidget {
  const GameStoreMembershipPrice(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var end = 0;
    for (final number
        in RegExp(r'[0-9٠-٩۰-۹][0-9٠-٩۰-۹.,٬٫]*').allMatches(label)) {
      if (number.start > end) {
        spans.add(TextSpan(text: label.substring(end, number.start)));
      }
      spans.add(TextSpan(
          text: number.group(0),
          style: const TextStyle(color: Color(0xFFFFDB3F))));
      end = number.end;
    }
    if (end < label.length) spans.add(TextSpan(text: label.substring(end)));
    return Text.rich(TextSpan(children: spans),
        maxLines: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.25,
            shadows: [
              Shadow(
                  color: Color(0xFF34340B), offset: Offset(0, 2), blurRadius: 2)
            ]));
  }
}

class GameStoreArtworkLabel {
  const GameStoreArtworkLabel(
      {required this.area, required this.cleanStrip, this.child});
  final Rect area;
  final Rect cleanStrip;
  final Widget? child;
}

/// Preserve the supplied return-reward frame and button while replacing baked
/// account data with real streak, ad and download-reward state.
class GameStoreReturnRewardCard extends StatelessWidget {
  const GameStoreReturnRewardCard(
      {super.key,
      required this.asset,
      required this.sourceFrame,
      required this.labels,
      required this.action,
      required this.imageKey,
      required this.actionKey,
      this.onPressed});
  final String asset;
  final Rect sourceFrame;
  final List<GameStoreArtworkLabel> labels;
  final Widget action;
  final Key imageKey;
  final Key actionKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: .83,
        child: LayoutBuilder(builder: (context, constraints) {
          final scaleX = constraints.maxWidth / sourceFrame.width;
          final scaleY = constraints.maxHeight / sourceFrame.height;
          final image = Rect.fromLTWH(-sourceFrame.left * scaleX,
              -sourceFrame.top * scaleY, scaleX, scaleY);
          Rect map(Rect source) => Rect.fromLTRB(
              image.left + source.left * scaleX,
              image.top + source.top * scaleY,
              image.left + source.right * scaleX,
              image.top + source.bottom * scaleY);
          return Stack(children: [
            Positioned.fromRect(
                rect: image,
                child: InkWell(
                    onTap: onPressed,
                    child: Image.asset(asset,
                        key: imageKey,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true))),
            for (final label in labels)
              Positioned.fromRect(
                  rect: map(label.area),
                  child: LayoutBuilder(
                      builder: (context, area) => Stack(children: [
                            Positioned.fill(
                                child: ClipRect(
                                    child: Stack(children: [
                              Positioned(
                                  left: -label.cleanStrip.left /
                                      label.cleanStrip.width *
                                      area.maxWidth,
                                  top: -label.cleanStrip.top /
                                      label.cleanStrip.height *
                                      area.maxHeight,
                                  width: area.maxWidth / label.cleanStrip.width,
                                  height:
                                      area.maxHeight / label.cleanStrip.height,
                                  child: Image.asset(asset,
                                      fit: BoxFit.fill,
                                      excludeFromSemantics: true)),
                            ]))),
                            if (label.child != null)
                              Positioned.fill(child: label.child!),
                          ]))),
            Positioned.fromRect(
                rect: map(const Rect.fromLTRB(.102, .741, .90, .912)),
                child: SizedBox(key: actionKey, child: action)),
          ]);
        }),
      );
}

/// Supplied character art, aligned by its visible frame rather than transparent
/// margins. The original green button keeps a native action and live label.
class GameStoreCharacterCard extends StatelessWidget {
  const GameStoreCharacterCard(
      {super.key,
      required this.gems,
      required this.title,
      required this.label,
      required this.onPressed});
  final bool gems;
  final String title, label;
  final VoidCallback? onPressed;

  String get asset => gems
      ? 'assets/store/character_talia.webp'
      : 'assets/store/character_fahad.webp';

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1452 / 1026,
        child: LayoutBuilder(builder: (context, area) {
          final scale = area.maxWidth / 1452;
          final frameLeft = gems ? 26.0 : 38.0;
          final sourceWidth = gems ? 1516.0 : 1520.0;
          Rect map(Rect rect) => Rect.fromLTWH((rect.left - frameLeft) * scale,
              (rect.top - 18) * scale, rect.width * scale, rect.height * scale);
          final labelArea = gems
              ? const Rect.fromLTRB(605, 774, 1044, 886)
              : const Rect.fromLTRB(594, 774, 1073, 886);
          final strip = gems
              ? const Rect.fromLTRB(1050, 774, 1058, 886)
              : const Rect.fromLTRB(1081, 774, 1089, 886);
          final button = map(gems
              ? const Rect.fromLTRB(390, 730, 1114, 925)
              : const Rect.fromLTRB(402, 730, 1126, 925));
          return Opacity(
              opacity: onPressed == null ? .65 : 1,
              child: Stack(children: [
                Positioned(
                    left: -frameLeft * scale,
                    top: -18 * scale,
                    width: sourceWidth * scale,
                    height: 1112 * scale,
                    child: Image.asset(asset,
                        fit: BoxFit.fill, excludeFromSemantics: true)),
                Positioned.fromRect(
                    rect: map(labelArea),
                    child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent
                            ], stops: [
                              0,
                              .02,
                              .98,
                              1
                            ]).createShader(rect),
                        child: ClipRect(
                            child: LayoutBuilder(
                                builder: (context, patch) => Stack(children: [
                                      Positioned(
                                          left: -strip.left /
                                              strip.width *
                                              patch.maxWidth,
                                          top: -strip.top /
                                              strip.height *
                                              patch.maxHeight,
                                          width: sourceWidth /
                                              strip.width *
                                              patch.maxWidth,
                                          height: 1112 /
                                              strip.height *
                                              patch.maxHeight,
                                          child: Image.asset(asset,
                                              fit: BoxFit.fill,
                                              excludeFromSemantics: true)),
                                    ]))))),
                Positioned.fromRect(
                    rect: map(labelArea),
                    child: IgnorePointer(
                        child: ExcludeSemantics(
                            child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text(label,
                                    maxLines: 1,
                                    style: const TextStyle(
                                        fontSize: 64,
                                        height: 1.25,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                              color: Color(0xFF174806),
                                              offset: Offset(2, 2),
                                              blurRadius: 2),
                                          Shadow(
                                              color: Color(0xFF174806),
                                              offset: Offset(-2, -2),
                                              blurRadius: 2),
                                        ])))))),
                Positioned.fromRect(
                    rect: Rect.fromCenter(
                        center: button.center,
                        width: button.width,
                        height: math.max(48, button.height)),
                    child: Tooltip(
                        message: '$title، $label',
                        child: Semantics(
                            label: '$title، $label',
                            child: FilledButton(
                                onPressed: onPressed,
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(48, 48),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18))),
                                child: const SizedBox.expand())))),
              ]));
        }),
      );
}

/// Native character card for roster additions with their own transparent art.
class GameStoreRosterCard extends StatelessWidget {
  const GameStoreRosterCard(
      {super.key,
      required this.name,
      required this.description,
      required this.asset,
      required this.label,
      required this.onPressed});
  final String name, description, asset, label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1452 / 1026,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFB5A0F1), width: 2),
            gradient: const RadialGradient(
                center: Alignment(0, -.3),
                radius: 1.3,
                colors: [Color(0xFF45316C), Color(0xFF171532)]),
          ),
          child: Column(children: [
            Expanded(
                child: Row(children: [
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text(name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: const TextStyle(
                            color: Color(0xFFFFDC92),
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(description,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFD5C9ED), fontSize: 11)),
                  ])),
              const SizedBox(width: 6),
              Expanded(
                  child: Image.asset(asset,
                      fit: BoxFit.contain, excludeFromSemantics: true)),
            ])),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Tooltip(
                  message: '$name، $label',
                  child: FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF079E77),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE5BE79))),
                    ),
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                  )),
            ),
          ]),
        ),
      );
}

/// Equal card bounds and a common price footer, independent of source padding.
class GameStoreCurrencyCard extends StatelessWidget {
  const GameStoreCurrencyCard({
    super.key,
    required this.asset,
    required this.art,
    required this.imageKey,
    required this.priceKey,
    required this.priceButton,
    this.onPressed,
  });

  final String asset;
  final Rect art;
  final Key imageKey;
  final Key priceKey;
  final Widget priceButton;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: .75,
        child: LayoutBuilder(builder: (context, constraints) {
          final border = (constraints.maxWidth * .012).clamp(1.5, 4.0);
          final radius = constraints.maxWidth * .06;
          return Container(
            padding: EdgeInsets.all(border),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF58ABFF),
                  Color(0xFFF784EC),
                  Color(0xFF8634C1)
                ],
                stops: [0, .5, 1],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - border),
              child: LayoutBuilder(
                  builder: (context, inside) => Stack(children: [
                        const Positioned.fill(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                              Color(0xFF32105F),
                              Color(0xFF230544)
                            ])))),
                        Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: inside.maxHeight * .79,
                            child: InkWell(
                                onTap: onPressed,
                                child: ClipRect(
                                    child: LayoutBuilder(
                                        builder: (context, area) =>
                                            Stack(children: [
                                              Positioned(
                                                  left: -art.left /
                                                      art.width *
                                                      area.maxWidth,
                                                  top: -art.top /
                                                      art.height *
                                                      area.maxHeight,
                                                  width:
                                                      area.maxWidth / art.width,
                                                  height: area.maxHeight /
                                                      art.height,
                                                  child: Image.asset(asset,
                                                      key: imageKey,
                                                      fit: BoxFit.fill,
                                                      excludeFromSemantics:
                                                          true)),
                                            ]))))),
                        Positioned(
                            left: inside.maxWidth * .035,
                            right: inside.maxWidth * .035,
                            bottom: inside.maxHeight * .025,
                            height: inside.maxHeight * .18,
                            child: SizedBox(key: priceKey, child: priceButton)),
                      ])),
            ),
          );
        }),
      );
}

/// A rounded, beveled green button with the highlights of the supplied art.
class GameStoreGlossySurface extends StatelessWidget {
  const GameStoreGlossySurface(
      {super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final height = constraints.maxHeight;
        final radius = height * .27;
        final rim = (height * .045).clamp(1.0, 3.0);
        return Container(
          padding: EdgeInsets.fromLTRB(rim, rim, rim, height * .09),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFF247B05) : const Color(0xFF2C5923),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF0A0621).withValues(alpha: .65),
                  offset: Offset(0, height * .045),
                  blurRadius: 2)
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius - rim),
              border: Border.all(
                  width: rim,
                  color: enabled
                      ? const Color(0xFFA9F653)
                      : const Color(0xFF69935B)),
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enabled
                      ? const [
                          Color(0xFFB5F51B),
                          Color(0xFF67E900),
                          Color(0xFF24B500)
                        ]
                      : const [
                          Color(0xFF6E9A46),
                          Color(0xFF4A7939),
                          Color(0xFF315B2B)
                        ],
                  stops: const [0, .44, 1]),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(radius - rim * 2),
                child: Stack(children: [
                  Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: height * .49,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: enabled ? .14 : .04),
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.elliptical(
                                      constraints.maxWidth * .5,
                                      height * .18))))),
                  if (enabled)
                    Positioned(
                        left: height * .16,
                        top: height * .075,
                        width: height * .38,
                        height: height * .15,
                        child: Transform.rotate(
                            angle: -.3,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .9),
                                    borderRadius:
                                        BorderRadius.circular(height * .1))))),
                  Positioned.fill(child: child),
                ])),
          ),
        );
      });
}

/// Align the visible ticket frames rather than their different PNG margins.
class GameStoreRewardBanner extends StatelessWidget {
  const GameStoreRewardBanner({
    super.key,
    required this.asset,
    required this.sourceFrame,
    required this.sourceButton,
    required this.imageKey,
    required this.actionKey,
    required this.action,
    this.onPressed,
  });

  final String asset;
  final Rect sourceFrame;
  final Rect sourceButton;
  final Key imageKey;
  final Key actionKey;
  final Widget action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 4.35,
        child: LayoutBuilder(builder: (context, constraints) {
          final frame = Rect.fromLTRB(
              constraints.maxWidth * .02,
              constraints.maxHeight * .16,
              constraints.maxWidth * .98,
              constraints.maxHeight * .98);
          final scaleX = frame.width / sourceFrame.width;
          final scaleY = frame.height / sourceFrame.height;
          final image = Rect.fromLTWH(frame.left - sourceFrame.left * scaleX,
              frame.top - sourceFrame.top * scaleY, scaleX, scaleY);
          final button = Rect.fromLTRB(
              image.left + sourceButton.left * scaleX,
              image.top + sourceButton.top * scaleY,
              image.left + sourceButton.right * scaleX,
              image.top + sourceButton.bottom * scaleY);
          return Stack(children: [
            Positioned.fromRect(
                rect: image,
                child: InkWell(
                    onTap: onPressed,
                    child: Image.asset(asset,
                        key: imageKey,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true))),
            Positioned.fromRect(
                rect: button, child: SizedBox(key: actionKey, child: action)),
          ]);
        }),
      );
}

import 'package:flutter/material.dart';
import 'adaptive_asset_image.dart';

const gameStoreNavigationAsset = 'assets/store/navigation.webp';

class _NavigationSlice extends StatelessWidget {
  const _NavigationSlice(this.source);
  final Rect source;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: LayoutBuilder(
            builder: (context, area) => Stack(children: [
                  Positioned(
                      left: -source.left / source.width * area.maxWidth,
                      top: -source.top / source.height * area.maxHeight,
                      width: area.maxWidth / source.width,
                      height: area.maxHeight / source.height,
                      child: adaptiveAssetImage(gameStoreNavigationAsset,
                          fit: BoxFit.fill, excludeFromSemantics: true)),
                ])),
      );
}

class GameStoreTopBarArtwork extends StatelessWidget {
  const GameStoreTopBarArtwork({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, area) {
        final cap = area.maxHeight * 151 / 405;
        return Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              SizedBox(
                  width: cap,
                  child: const _NavigationSlice(Rect.fromLTRB(
                      29 / 3168, 40 / 474, 180 / 3168, 445 / 474))),
              const Expanded(
                  child:
                      // Match the inner edge of both mirrored end caps so the
                      // blue gradient continues without a vertical seam.
                      _NavigationSlice(Rect.fromLTRB(
                          179.5 / 3168, 40 / 474, 180.5 / 3168, 445 / 474))),
              SizedBox(
                  width: cap,
                  child: Transform.flip(
                      flipX: true,
                      child: const _NavigationSlice(Rect.fromLTRB(
                          29 / 3168, 40 / 474, 180 / 3168, 445 / 474)))),
            ]));
      });
}

class GameStoreNavigationSelection extends StatelessWidget {
  const GameStoreNavigationSelection({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, area) {
        const panel =
            Rect.fromLTRB(2045 / 3168, 62 / 474, 2885 / 3168, 420 / 474);
        const erase =
            Rect.fromLTRB(2360 / 3168, 62 / 474, 2580 / 3168, 420 / 474);
        final label = Rect.fromLTRB(
            (erase.left - panel.left) / panel.width * area.maxWidth,
            (erase.top - panel.top) / panel.height * area.maxHeight,
            (erase.right - panel.left) / panel.width * area.maxWidth,
            (erase.bottom - panel.top) / panel.height * area.maxHeight);
        return ClipRRect(
            borderRadius: BorderRadius.circular(area.maxHeight * .14),
            child: Stack(children: [
              const Positioned.fill(child: _NavigationSlice(panel)),
              Positioned.fromRect(
                  rect: label,
                  child: const _NavigationSlice(Rect.fromLTRB(
                      2200 / 3168, 62 / 474, 2210 / 3168, 420 / 474))),
            ]));
      });
}

// Bounds and contours use the same pixel coordinates in the 3168 x 474 atlas.
// Keep each crop and its outline together when replacing the source artwork.
class _NavigationIconArtwork {
  const _NavigationIconArtwork(this.bounds, this.contours);
  final Rect bounds;
  final List<List<Offset>> contours;
  Rect get source => Rect.fromLTRB(bounds.left / 3168, bounds.top / 474,
      bounds.right / 3168, bounds.bottom / 474);
}

class GameStoreNavIcon extends StatelessWidget {
  const GameStoreNavIcon({super.key, required this.index, this.size = 44});
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final artwork = _navigationIcons[index]!;
    return SizedBox(
        width: size,
        height: size,
        child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
                width: artwork.bounds.width,
                height: artwork.bounds.height,
                child: ClipPath(
                    clipper: _NavigationIconClipper(index),
                    child: _NavigationSlice(artwork.source)))));
  }
}

class _NavigationIconClipper extends CustomClipper<Path> {
  const _NavigationIconClipper(this.index);
  final int index;

  @override
  Path getClip(Size size) {
    final artwork = _navigationIcons[index]!;
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final contour in artwork.contours) {
      path.addPolygon(
          contour
              .map((point) => Offset(
                  point.dx / artwork.bounds.width * size.width,
                  point.dy / artwork.bounds.height * size.height))
              .toList(),
          true);
    }
    return path;
  }

  @override
  bool shouldReclip(_NavigationIconClipper oldClipper) =>
      oldClipper.index != index;
}

// Traced outlines exclude the painted atlas background and preserve inner holes.
const _navigationIcons = <int, _NavigationIconArtwork>{
  0: _NavigationIconArtwork(Rect.fromLTWH(2377, 88, 177, 204), [
    [
      Offset(30, 0),
      Offset(148, 0),
      Offset(155, 4),
      Offset(156, 8),
      Offset(159, 8),
      Offset(158, 10),
      Offset(160, 10),
      Offset(163, 20),
      Offset(163, 38),
      Offset(166, 40),
      Offset(165, 44),
      Offset(167, 44),
      Offset(168, 53),
      Offset(171, 56),
      Offset(173, 68),
      Offset(175, 68),
      Offset(177, 83),
      Offset(173, 98),
      Offset(166, 102),
      Offset(167, 104),
      Offset(164, 104),
      Offset(164, 182),
      Offset(160, 192),
      Offset(152, 200),
      Offset(143, 204),
      Offset(33, 204),
      Offset(24, 200),
      Offset(15, 190),
      Offset(12, 176),
      Offset(12, 106),
      Offset(9, 104),
      Offset(10, 102),
      Offset(5, 100),
      Offset(1, 92),
      Offset(0, 75),
      Offset(8, 54),
      Offset(7, 52),
      Offset(9, 51),
      Offset(8, 48),
      Offset(11, 45),
      Offset(10, 42),
      Offset(13, 40),
      Offset(12, 36),
      Offset(15, 34),
      Offset(13, 32),
      Offset(16, 12),
      Offset(23, 6),
      Offset(22, 4),
      Offset(30, 2),
    ],
  ]),
  1: _NavigationIconArtwork(Rect.fromLTWH(1254, 153, 213, 143), [
    [
      Offset(74, 0),
      Offset(75, 2),
      Offset(72, 7),
      Offset(143, 8),
      Offset(175, 41),
      Offset(168, 49),
      Offset(190, 56),
      Offset(196, 62),
      Offset(204, 82),
      Offset(207, 82),
      Offset(213, 91),
      Offset(208, 91),
      Offset(209, 93),
      Offset(202, 95),
      Offset(141, 142),
      Offset(138, 142),
      Offset(136, 139),
      Offset(129, 111),
      Offset(106, 142),
      Offset(100, 138),
      Offset(80, 111),
      Offset(74, 143),
      Offset(69, 143),
      Offset(6, 98),
      Offset(0, 90),
      Offset(11, 70),
      Offset(12, 66),
      Offset(10, 64),
      Offset(13, 64),
      Offset(11, 61),
      Offset(19, 60),
      Offset(22, 57),
      Offset(40, 51),
      Offset(35, 46),
      Offset(33, 40),
      Offset(56, 18),
      Offset(48, 14),
      Offset(59, 15),
      Offset(60, 10),
      Offset(57, 8),
      Offset(61, 9),
      Offset(62, 4),
      Offset(66, 4),
      Offset(68, 7),
    ],
  ]),
  2: _NavigationIconArtwork(Rect.fromLTWH(1712, 98, 234, 216), [
    [
      Offset(37, 0),
      Offset(63, 0),
      Offset(64, 2),
      Offset(71, 2),
      Offset(71, 4),
      Offset(85, 8),
      Offset(85, 10),
      Offset(94, 14),
      Offset(104, 24),
      Offset(114, 46),
      Offset(114, 60),
      Offset(112, 58),
      Offset(110, 68),
      Offset(102, 80),
      Offset(99, 80),
      Offset(97, 84),
      Offset(93, 84),
      Offset(93, 86),
      Offset(87, 86),
      Offset(87, 88),
      Offset(68, 88),
      Offset(67, 100),
      Offset(58, 108),
      Offset(47, 140),
      Offset(47, 145),
      Offset(53, 146),
      Offset(52, 148),
      Offset(58, 148),
      Offset(57, 150),
      Offset(63, 150),
      Offset(68, 142),
      Offset(71, 142),
      Offset(73, 138),
      Offset(83, 132),
      Offset(98, 112),
      Offset(111, 82),
      Offset(112, 68),
      Offset(115, 68),
      Offset(114, 60),
      Offset(117, 60),
      Offset(116, 54),
      Offset(118, 58),
      Offset(118, 46),
      Offset(122, 32),
      Offset(123, 30),
      Offset(125, 31),
      Offset(124, 26),
      Offset(126, 28),
      Offset(125, 24),
      Offset(129, 22),
      Offset(127, 20),
      Offset(131, 16),
      Offset(135, 16),
      Offset(137, 10),
      Offset(145, 12),
      Offset(148, 20),
      Offset(150, 18),
      Offset(150, 26),
      Offset(155, 26),
      Offset(157, 23),
      Offset(169, 24),
      Offset(172, 28),
      Offset(171, 35),
      Offset(173, 32),
      Offset(174, 40),
      Offset(178, 40),
      Offset(179, 36),
      Offset(183, 36),
      Offset(182, 32),
      Offset(189, 32),
      Offset(185, 30),
      Offset(190, 30),
      Offset(190, 33),
      Offset(196, 36),
      Offset(195, 40),
      Offset(197, 38),
      Offset(196, 46),
      Offset(197, 44),
      Offset(198, 46),
      Offset(200, 44),
      Offset(212, 44),
      Offset(212, 46),
      Offset(216, 46),
      Offset(217, 50),
      Offset(220, 50),
      Offset(222, 46),
      Offset(229, 46),
      Offset(223, 48),
      Offset(229, 48),
      Offset(230, 54),
      Offset(232, 50),
      Offset(234, 56),
      Offset(232, 82),
      Offset(218, 110),
      Offset(202, 158),
      Offset(184, 188),
      Offset(160, 214),
      Offset(153, 216),
      Offset(147, 214),
      Offset(142, 200),
      Offset(137, 200),
      Offset(133, 204),
      Offset(126, 202),
      Offset(122, 196),
      Offset(122, 188),
      Offset(118, 188),
      Offset(114, 192),
      Offset(107, 192),
      Offset(103, 186),
      Offset(102, 178),
      Offset(87, 180),
      Offset(84, 176),
      Offset(82, 164),
      Offset(67, 166),
      Offset(63, 174),
      Offset(60, 174),
      Offset(61, 184),
      Offset(55, 202),
      Offset(44, 200),
      Offset(44, 198),
      Offset(34, 196),
      Offset(34, 194),
      Offset(28, 194),
      Offset(24, 200),
      Offset(11, 200),
      Offset(11, 198),
      Offset(6, 198),
      Offset(2, 194),
      Offset(0, 190),
      Offset(0, 176),
      Offset(3, 172),
      Offset(6, 158),
      Offset(8, 158),
      Offset(14, 136),
      Offset(16, 136),
      Offset(16, 130),
      Offset(18, 130),
      Offset(24, 106),
      Offset(26, 106),
      Offset(25, 104),
      Offset(28, 100),
      Offset(24, 84),
      Offset(27, 78),
      Offset(31, 77),
      Offset(31, 74),
      Offset(21, 66),
      Offset(22, 64),
      Offset(18, 62),
      Offset(19, 60),
      Offset(17, 60),
      Offset(16, 54),
      Offset(14, 54),
      Offset(11, 40),
      Offset(12, 26),
      Offset(19, 12),
      Offset(28, 4),
      Offset(31, 4),
      Offset(31, 2),
      Offset(36, 2),
    ],
    [
      Offset(46, 30),
      Offset(40, 36),
      Offset(40, 42),
      Offset(45, 50),
      Offset(48, 50),
      Offset(48, 52),
      Offset(59, 52),
      Offset(68, 60),
      Offset(75, 60),
      Offset(81, 56),
      Offset(83, 48),
      Offset(78, 40),
      Offset(68, 36),
      Offset(68, 34),
      Offset(63, 34),
      Offset(63, 32),
      Offset(57, 32),
      Offset(57, 30),
    ],
  ]),
  3: _NavigationIconArtwork(Rect.fromLTWH(753, 128, 198, 210), [
    [
      Offset(133, 0),
      Offset(146, 0),
      Offset(151, 4),
      Offset(153, 12),
      Offset(168, 12),
      Offset(154, 14),
      Offset(172, 14),
      Offset(170, 16),
      Offset(177, 18),
      Offset(178, 21),
      Offset(176, 22),
      Offset(179, 22),
      Offset(177, 23),
      Offset(180, 24),
      Offset(178, 25),
      Offset(179, 28),
      Offset(181, 26),
      Offset(180, 34),
      Offset(182, 32),
      Offset(182, 35),
      Offset(180, 38),
      Offset(181, 44),
      Offset(183, 40),
      Offset(182, 52),
      Offset(198, 162),
      Offset(198, 178),
      Offset(192, 188),
      Offset(185, 190),
      Offset(185, 192),
      Offset(175, 192),
      Offset(175, 194),
      Offset(159, 194),
      Offset(159, 196),
      Offset(145, 196),
      Offset(145, 198),
      Offset(130, 198),
      Offset(130, 200),
      Offset(115, 200),
      Offset(115, 202),
      Offset(100, 202),
      Offset(100, 204),
      Offset(84, 204),
      Offset(84, 206),
      Offset(70, 206),
      Offset(70, 208),
      Offset(56, 208),
      Offset(56, 210),
      Offset(32, 210),
      Offset(32, 208),
      Offset(24, 204),
      Offset(18, 182),
      Offset(3, 60),
      Offset(1, 58),
      Offset(2, 52),
      Offset(0, 49),
      Offset(0, 46),
      Offset(2, 48),
      Offset(1, 44),
      Offset(3, 44),
      Offset(6, 38),
      Offset(4, 36),
      Offset(5, 34),
      Offset(10, 34),
      Offset(8, 32),
      Offset(17, 32),
      Offset(11, 30),
      Offset(24, 28),
      Offset(25, 22),
      Offset(27, 28),
      Offset(26, 20),
      Offset(28, 20),
      Offset(28, 16),
      Offset(33, 16),
      Offset(30, 14),
      Offset(35, 12),
      Offset(45, 14),
      Offset(42, 16),
      Offset(47, 16),
      Offset(45, 18),
      Offset(49, 18),
      Offset(48, 22),
      Offset(50, 24),
      Offset(89, 22),
      Offset(78, 20),
      Offset(107, 20),
      Offset(95, 18),
      Offset(123, 18),
      Offset(111, 16),
      Offset(126, 16),
      Offset(127, 8),
      Offset(130, 8),
      Offset(128, 6),
    ],
  ]),
  4: _NavigationIconArtwork(Rect.fromLTWH(259, 120, 189, 226), [
    [
      Offset(120, 0),
      Offset(137, 0),
      Offset(137, 2),
      Offset(140, 2),
      Offset(146, 14),
      Offset(154, 16),
      Offset(159, 26),
      Offset(165, 64),
      Offset(189, 174),
      Offset(189, 188),
      Offset(184, 196),
      Offset(174, 198),
      Offset(173, 200),
      Offset(131, 208),
      Offset(131, 210),
      Offset(123, 210),
      Offset(123, 212),
      Offset(114, 212),
      Offset(114, 214),
      Offset(89, 218),
      Offset(89, 220),
      Offset(81, 220),
      Offset(80, 222),
      Offset(64, 224),
      Offset(63, 226),
      Offset(47, 226),
      Offset(39, 222),
      Offset(30, 210),
      Offset(0, 68),
      Offset(0, 42),
      Offset(6, 30),
      Offset(10, 26),
      Offset(14, 26),
      Offset(14, 24),
      Offset(46, 18),
      Offset(46, 16),
      Offset(54, 16),
      Offset(55, 14),
      Offset(64, 14),
      Offset(64, 12),
      Offset(73, 12),
      Offset(73, 10),
      Offset(82, 10),
      Offset(82, 8),
      Offset(91, 8),
      Offset(91, 6),
      Offset(110, 4),
      Offset(110, 2),
      Offset(120, 2),
    ],
  ]),
};

import 'package:flutter/material.dart';

/// The iconic golden-bordered blue podium nameplate ("أرض التحدي")
/// that sits in front of the host character, matching `podiumhost.png` from native gameplay.
class HostPodiumPlate extends StatelessWidget {
  const HostPodiumPlate({
    super.key,
    this.title = 'أرض التحدي',
    this.width = 152.0,
    this.onTap,
  });

  static const nativeAspectRatio = 152 / 64;

  /// Name displayed inside the podium plate (defaults to "أرض التحدي").
  final String title;

  /// Width of the podium plate (height is proportional ~2.37:1).
  final double width;

  /// Optional tap callback.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final height = width / nativeAspectRatio;

    final plate = SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background podium drawable (podiumhost.png)
          Image.asset(
            'assets/presenter/podiumhost.png',
            width: width,
            height: height,
            fit: BoxFit.fill,
            excludeFromSemantics: true,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),

          // Plate Text with subtle gold/black shadow
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * 16 / 152,
              vertical: height * 0.08,
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Baloo',
                fontFamilyFallback: const ['NotoSansArabic'],
                fontSize: height * 19 / 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
                shadows: const [
                  Shadow(
                    color: Color(0xCC000000),
                    offset: Offset(0, 1.8),
                    blurRadius: 3.5,
                  ),
                  Shadow(
                    color: Color(0x66D97706),
                    offset: Offset(0, -0.8),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: plate,
      );
    }

    return plate;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../models/store_catalog.dart';
import '../screens/home/store_screen.dart';
import '../services/in_app_purchase_service.dart';
import 'game_store_widgets.dart';

/// A factual membership preview; checkout and disclosures live in the store.
class SpecialOfferDialog extends StatelessWidget {
  const SpecialOfferDialog({super.key});

  static const _shownKey = 'commerce.membershipPreviewAt';

  static Future<void> show(BuildContext context) async {
    if (!context.mounted) return;
    await markShown();
    if (!context.mounted) return;
    await showDialog<void>(
        context: context, builder: (_) => const SpecialOfferDialog());
  }

  static Future<bool> shouldShowAuto({bool isVip = false}) async {
    if (isVip) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_shownKey);
      // Give a new player a week to experience the game before a membership
      // suggestion. Afterwards show at most once each week.
      if (last == null) {
        await prefs.setInt(_shownKey, DateTime.now().millisecondsSinceEpoch);
        return false;
      }
      return DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(last))
              .inDays >=
          7;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_shownKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final iap = context.watch<InAppPurchaseService>();
    final detail = iap.getProductDetails('vip_monthly');
    final price = app.isVip
        ? 'عضويتك فعّالة'
        : iap.isLoading
            ? 'جارٍ تحميل السعر…'
            : iap.isAvailable && detail != null && detail.price.isNotEmpty
                ? '${detail.price} / شهر'
                : 'السعر غير متاح حالياً';
    final size = MediaQuery.sizeOf(context);
    final safeArea = MediaQuery.paddingOf(context);
    final width = math.min(
        900.0,
        math.min(
            size.width - safeArea.horizontal - 24,
            (size.height - safeArea.vertical - 24) *
                _PreviewArtwork.aspectRatio));
    final actionLabel = app.isVip ? 'إدارة العضوية' : 'استكشاف العضوية';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: width,
          child: RepaintBoundary(
            key: const ValueKey('champions-club-preview'),
            child: _PreviewArtwork(
              price: price,
              actionLabel: actionLabel,
              onClose: () => Navigator.pop(context),
              onExplore: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute<void>(
                    builder: (_) => const StoreScreen(
                        initialKind: StoreProductKind.subscription)));
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The supplied frame and buttons stay intact; only live labels are overlaid.
class _PreviewArtwork extends StatelessWidget {
  const _PreviewArtwork(
      {required this.price,
      required this.actionLabel,
      required this.onClose,
      required this.onExplore});
  final String price;
  final String actionLabel;
  final VoidCallback onClose;
  final VoidCallback onExplore;
  static const asset = 'assets/store/champions_club_preview.webp';
  static const frame = Rect.fromLTRB(.032, .027, .968, .999);
  static const aspectRatio = (2400 * .936) / (1792 * .972);

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(builder: (context, area) {
          Rect map(Rect source) => Rect.fromLTRB(
              (source.left - frame.left) / frame.width * area.maxWidth,
              (source.top - frame.top) / frame.height * area.maxHeight,
              (source.right - frame.left) / frame.width * area.maxWidth,
              (source.bottom - frame.top) / frame.height * area.maxHeight);
          Widget cleanLabel(Rect region, Rect strip, Widget label) =>
              Positioned.fromRect(
                  rect: map(region),
                  child: Stack(children: [
                    Positioned.fill(child: _PreviewSlice(strip)),
                    Positioned.fill(child: label),
                  ]));
          Rect touchTarget(Rect source) {
            final rect = map(source);
            return Rect.fromCenter(
                center: rect.center,
                width: math.max(48, rect.width),
                height: math.max(48, rect.height));
          }

          return Semantics(
            label: 'نادي الأبطال. وسع عالم أسئلتك واستمتع بجلسات أكثر هدوءاً. '
                'كل الفئات المميزة طوال مدة العضوية. '
                'بدون إعلانات إجبارية، إعلانات المكافآت اختيارية. '
                'المنافسة والترتيب يعتمدان على أدائك. '
                'اشتراك شهري يتجدد تلقائياً. يمكنك إلغاء التجديد من Google Play، '
                'وتستمر المزايا حتى نهاية الفترة المدفوعة.',
            child: Stack(children: [
              Positioned.fill(
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(area.maxWidth * .04),
                      child: const _PreviewSlice(frame))),
              // A nearby horizontal strip preserves the background's color
              // across the price area; soft edges blend it into the artwork.
              Positioned.fromRect(
                  rect: map(const Rect.fromLTRB(.585, .595, .935, .714)),
                  child: const _PriceBackground()),
              Positioned.fromRect(
                  rect: map(const Rect.fromLTRB(.605, .620, .911, .692)),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                          fit: BoxFit.contain,
                          child: GameStoreText(price,
                              size: 36, color: const Color(0xFFFFDA7A))))),
              cleanLabel(
                  const Rect.fromLTRB(.344, .857, .682, .926),
                  const Rect.fromLTRB(.72, .857, .75, .926),
                  const SizedBox.shrink()),
              Positioned.fromRect(
                  rect:
                      touchTarget(const Rect.fromLTRB(.089, .099, .178, .217)),
                  child: _artworkButton(label: 'إغلاق', onPressed: onClose)),
              Positioned.fromRect(
                  rect:
                      touchTarget(const Rect.fromLTRB(.089, .838, .914, .944)),
                  child: _artworkButton(
                      label: actionLabel,
                      onPressed: onExplore,
                      child: FractionallySizedBox(
                          widthFactor: .56,
                          heightFactor: .57,
                          child: FittedBox(
                              fit: BoxFit.contain,
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GameStoreText(actionLabel, size: 36),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.arrow_back_rounded,
                                        color: Colors.white,
                                        size: 36,
                                        textDirection: TextDirection.ltr),
                                  ]))))),
            ]),
          );
        }),
      );

  Widget _artworkButton(
          {required String label,
          required VoidCallback onPressed,
          Widget? child}) =>
      Tooltip(
          message: label,
          child: Semantics(
              label: label,
              button: true,
              child: TextButton(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: ExcludeSemantics(
                      child: child ?? const SizedBox.expand()))));
}

class _PriceBackground extends StatelessWidget {
  const _PriceBackground();

  @override
  Widget build(BuildContext context) => ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ], stops: [
            0,
            .06,
            .94,
            1
          ]).createShader(rect),
      child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent
                  ],
                  stops: [
                    0,
                    .14,
                    .86,
                    1
                  ]).createShader(rect),
          child: const _PreviewSlice(Rect.fromLTRB(.585, .695, .935, .700))));
}

class _PreviewSlice extends StatelessWidget {
  const _PreviewSlice(this.source);
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
                      child: Image.asset(_PreviewArtwork.asset,
                          fit: BoxFit.fill, excludeFromSemantics: true)),
                ])),
      );
}

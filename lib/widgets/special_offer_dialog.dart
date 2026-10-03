import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../models/store_catalog.dart';
import '../screens/home/store_screen.dart';
import '../services/in_app_purchase_service.dart';

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF121A33),
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 510),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFFF9C969), size: 34),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('نادي الأبطال',
                            style: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.w800))),
                    IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                      app.isVip
                          ? 'عضويتك فعالة. استمتع بمزاياك.'
                          : 'وسع عالم أسئلتك واستمتع بجلسات أكثر هدوءاً.',
                      style: const TextStyle(
                          color: Color(0xFFB4BED8), fontSize: 15)),
                  const SizedBox(height: 20),
                  const _Benefit(
                      icon: Icons.grid_view_rounded,
                      text: 'كل الفئات المميزة طوال مدة العضوية'),
                  const _Benefit(
                      icon: Icons.block_rounded,
                      text: 'بدون إعلانات إجبارية • إعلانات المكافآت اختيارية'),
                  const _Benefit(
                      icon: Icons.balance_rounded,
                      text: 'المنافسة والترتيب يعتمدان على أدائك'),
                  const SizedBox(height: 16),
                  if (detail != null)
                    Text('${detail.price} / شهر',
                        style: const TextStyle(
                            fontSize: 22,
                            color: Color(0xFFF9C969),
                            fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                      'اشتراك شهري يتجدد تلقائياً. يمكنك إلغاء التجديد من Google Play، وتستمر المزايا حتى نهاية الفترة المدفوعة.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB4BED8))),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          navigator.push(MaterialPageRoute<void>(
                              builder: (_) => const StoreScreen(
                                  initialKind: StoreProductKind.subscription)));
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                            app.isVip ? 'إدارة العضوية' : 'استكشاف العضوية'),
                      )),
                ]),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF8BDDD0), size: 21),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14)))
        ]),
      );
}

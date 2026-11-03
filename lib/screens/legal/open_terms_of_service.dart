import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/privacy_policy_content.g.dart';
import '../../services/native_bridge_service.dart';

/// Uses the published terms as the single current version for every entry point.
Future<void> openTermsOfService(BuildContext context,
    {bool isArabic = true}) async {
  final opened = await NativeBridgeService()
      .openExternalUrl(PrivacyPolicyContent.termsUrl);
  if (!context.mounted || opened) return;
  await Clipboard.setData(
      const ClipboardData(text: PrivacyPolicyContent.termsUrl));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(isArabic
        ? 'تم نسخ رابط بنود الخدمة لفتحه في المتصفح'
        : 'Terms of Service link copied. Open it in your browser.'),
  ));
}

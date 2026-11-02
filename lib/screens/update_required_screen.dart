import 'package:flutter/material.dart';

import '../models/app_update_policy.dart';

/// A static, lightweight screen; gameplay is not mounted behind it.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({
    super.key,
    required this.policy,
    required this.onUpdate,
    required this.onRetry,
    this.checking = false,
    this.openingStore = false,
    this.error,
  });

  final AppUpdatePolicy policy;
  final VoidCallback onUpdate, onRetry;
  final bool checking, openingStore;
  final String? error;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/home/lobby_background.webp',
                  fit: BoxFit.cover,
                  cacheWidth: 1280,
                  excludeFromSemantics: true),
              const ColoredBox(color: Color(0xD9081225)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Container(
                        key: const ValueKey('required-update-screen'),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xF010203A),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFD9B56D)),
                        ),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.system_update_rounded,
                              size: 52, color: Color(0xFFFFD676)),
                          const SizedBox(height: 12),
                          const Text('تحديث اللعبة مطلوب',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFD676))),
                          const SizedBox(height: 12),
                          Text(policy.message,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontSize: 17, height: 1.6)),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey('required-update-store'),
                              onPressed: openingStore ? null : onUpdate,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(openingStore
                                  ? 'جارٍ فتح المتجر…'
                                  : 'تحديث الآن'),
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                  backgroundColor: const Color(0xFFE6BC64),
                                  foregroundColor: const Color(0xFF14203A)),
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('required-update-retry'),
                            onPressed: checking ? null : onRetry,
                            child: Text(
                                checking ? 'جارٍ التحقق…' : 'إعادة التحقق'),
                          ),
                          if (error != null)
                            Text(error!,
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: Color(0xFFFFB7A9))),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

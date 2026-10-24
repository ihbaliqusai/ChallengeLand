import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../widgets/adaptive_asset_image.dart';
import '../legal/privacy_policy_screen.dart';
import '../../core/constants/app_routes.dart';

class LoginBottomSheet extends StatefulWidget {
  const LoginBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.user != null || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    await showModalBottomSheet<void>(
      routeSettings: const RouteSettings(name: AppRoutes.guestSignIn),
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: .22),
      constraints: const BoxConstraints(maxWidth: 440),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const LoginBottomSheet(),
      ),
    );
  }

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> {
  static const _purple = Color(0xFF7447F6);
  bool _acceptedPrivacy = false;
  bool _signingIn = false;
  String? _error;

  Future<void> _signIn() async {
    if (_signingIn) return;
    if (!_acceptedPrivacy) {
      setState(() => _error = 'يرجى الموافقة على سياسة الخصوصية أولاً');
      return;
    }
    final state = context.read<AppState>();
    if (!state.isOnline) {
      setState(() => _error = 'تحقق من اتصال الإنترنت ثم حاول مجدداً');
      return;
    }

    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await state.signInWithGoogle();
      if (mounted && state.user != null) Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code != 'cancelled' && error.code != 'sign_in_canceled') {
        setState(
          () => _error = error.code == 'network-request-failed'
              ? 'تحقق من اتصال الإنترنت ثم حاول مجدداً'
              : 'تعذر تسجيل الدخول. يرجى المحاولة مرة أخرى',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تسجيل الدخول. يرجى المحاولة مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _signingIn || context.watch<AppState>().isBusy;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const ValueKey('close-login-sheet'),
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: const EdgeInsets.all(4),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF444444),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تسجيل الدخول',
                style: TextStyle(
                  color: _purple,
                  fontSize: 26,
                  fontFamily: 'NotoSansArabic',
                  fontWeight: FontWeight.w900,
                  fontVariations: [
                    FontVariation('wght', 900),
                    FontVariation('wdth', 85),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'أهلاً بك!\nقم بتسجيل الدخول للحفاظ على تقدمك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF161616),
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  key: const ValueKey('google-sign-in'),
                  onPressed: busy ? null : _signIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _purple,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _purple, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 1,
                    shadowColor: Colors.black26,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _purple,
                          ),
                        )
                      : Row(
                          children: [
                            adaptiveAssetImage(
                              'assets/ui/google.png',
                              width: 22,
                              height: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'تسجيل دخول بواسطة جوجل',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 40,
                    child: Checkbox(
                      key: const ValueKey('login-privacy-checkbox'),
                      value: _acceptedPrivacy,
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              _acceptedPrivacy = value ?? false;
                              _error = null;
                            }),
                      semanticLabel: 'أوافق على سياسة الخصوصية',
                      activeColor: _purple,
                      checkColor: Colors.white,
                      side: const BorderSide(color: _purple, width: 1.2),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'قرأت ',
                          style: TextStyle(
                            color: Color(0xFF161616),
                            fontSize: 14,
                          ),
                        ),
                        InkWell(
                          key: const ValueKey('login-privacy-link'),
                          onTap: busy
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const PrivacyPolicyScreen(),
                                  ),
                                ),
                          child: const Text(
                            'سياسة الخصوصية',
                            style: TextStyle(
                              color: _purple,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                              decorationColor: _purple,
                            ),
                          ),
                        ),
                        const Text(
                          ' وأوافق عليها.',
                          style: TextStyle(
                            color: Color(0xFF161616),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

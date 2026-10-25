import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../screens/auth/first_run_challenge_screen.dart';
import '../../screens/auth/login_bottom_sheet.dart';
import 'host_guide_character.dart';

/// The assistant dialog that opens whenever the user taps the persistent Guide button.
class GuideAssistantDialog extends StatefulWidget {
  const GuideAssistantDialog({
    super.key,
    required this.onRestartTour,
  });

  final VoidCallback onRestartTour;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onRestartTour,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => GuideAssistantDialog(onRestartTour: onRestartTour),
    );
  }

  @override
  State<GuideAssistantDialog> createState() => _GuideAssistantDialogState();
}

class _GuideAssistantDialogState extends State<GuideAssistantDialog> {
  bool _isSigningIn = false;
  String? _signInError;

  Future<void> _handleGoogleSignIn(AppState appState) async {
    if (_isSigningIn) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSigningIn = true;
      _signInError = null;
    });

    try {
      await appState.signInWithGoogle();
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      if (appState.user != null) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _signInError = e is FirebaseAuthException && e.code == 'cancelled'
            ? null
            : 'تعذّر تسجيل الدخول. حاول مجددًا أو اختر طريقة أخرى.';
      });
    }
  }

  void _openDemoPlay() {
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const FirstRunChallengeScreen(),
      ),
    );
  }

  void _restartTour() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    widget.onRestartTour();
  }

  void _openOtherLoginOptions() {
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    navigator.pop();
    LoginBottomSheet.show(navigator.context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final dialogWidth = (isLandscape ? size.width * 0.72 : size.width * 0.92)
        .clamp(320.0, 560.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: size.height * 0.92),
        child: _GuideDialogBody(
          closeKey: const ValueKey('close-guide-assistant'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Host with Speech Bubble
              HostGuideBubble(
                title: 'كيف أساعدك؟',
                text:
                    'اختر «إعادة الجولة» لشرح الأوضاع والمراحل والمتجر والشخصيات، أو «جرّب التحدي» لتتعلم باللعب.',
                hostHeight: isLandscape ? 170 : 190,
                bubbleWidth: dialogWidth,
                enableTypewriter: true,
                isTalking: true,
              ),

              const SizedBox(height: 12),

              // Action Options Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Option 1: Demo Gameplay (Free, instant)
                    _OptionButton(
                      icon: Icons.sports_esports_rounded,
                      title: 'جرّب التحدي مجانًا',
                      subtitle: 'تعرّف على الأسئلة والإجابة دون تسجيل دخول',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      onPressed: _openDemoPlay,
                    ),

                    const SizedBox(height: 10),

                    if (_signInError != null) ...[
                      Text(_signInError!,
                          style: const TextStyle(
                              color: Color(0xFFFFB8B8),
                              fontFamily: 'NotoSansArabic')),
                      const SizedBox(height: 8),
                    ],
                    // Option 2: Google Sign-in (Gmail)
                    _OptionButton(
                      icon: Icons.g_mobiledata_rounded,
                      iconSize: 34,
                      title: 'المتابعة بحساب Google',
                      subtitle: 'احفظ تقدمك وافتح المنافسة عبر الإنترنت',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                      loading: _isSigningIn,
                      onPressed: () => _handleGoogleSignIn(appState),
                    ),

                    const SizedBox(height: 10),

                    // Option 3: Replay Tour
                    _OptionButton(
                      icon: Icons.auto_stories_rounded,
                      title: 'إعادة الجولة التعريفية',
                      subtitle: 'شرح الأوضاع والمراحل والمتجر والشخصيات خطوة بخطوة',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                      ),
                      onPressed: _restartTour,
                    ),

                    const SizedBox(height: 12),

                    // Extra footer actions
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _openOtherLoginOptions,
                          icon: const Icon(Icons.mail_lock_rounded, size: 16),
                          label: const Text(
                            'خيارات تسجيل أخرى',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'إغلاق',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly prompt replacing the cold login required dialog.
class GuidePromptDialog extends StatefulWidget {
  const GuidePromptDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const GuidePromptDialog(),
    );
  }

  @override
  State<GuidePromptDialog> createState() => _GuidePromptDialogState();
}

class _GuidePromptDialogState extends State<GuidePromptDialog> {
  bool _isSigningIn = false;
  String? _signInError;

  Future<void> _handleGoogleSignIn(AppState appState) async {
    if (_isSigningIn) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSigningIn = true;
      _signInError = null;
    });

    try {
      await appState.signInWithGoogle();
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      if (appState.user != null) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _signInError = e is FirebaseAuthException && e.code == 'cancelled'
            ? null
            : 'تعذّر تسجيل الدخول. حاول مجددًا أو اختر طريقة أخرى.';
      });
    }
  }

  void _openDemoPlay() {
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const FirstRunChallengeScreen(),
      ),
    );
  }

  void _openOtherLoginOptions() {
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    navigator.pop();
    LoginBottomSheet.show(navigator.context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final dialogWidth = (isLandscape ? size.width * 0.65 : size.width * 0.90)
        .clamp(320.0, 520.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: size.height * 0.92),
        child: _GuideDialogBody(
          closeKey: const ValueKey('close-login-sheet'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Host with Speech Bubble
              HostGuideBubble(
                title: 'سجّل الدخول للمتابعة',
                text:
                    'سجّل الدخول لحفظ تقدمك واستخدام هذه الميزة. أو جرّب التحدي المجاني أولًا دون حساب.',
                hostHeight: isLandscape ? 170 : 190,
                bubbleWidth: dialogWidth,
                enableTypewriter: true,
                isTalking: true,
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Option 1: Demo Play
                    _OptionButton(
                      icon: Icons.sports_esports_rounded,
                      title: 'جرّب التحدي مجانًا',
                      subtitle: 'تحدٍّ تعريفي متاح دون حساب',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      onPressed: _openDemoPlay,
                    ),

                    const SizedBox(height: 10),

                    if (_signInError != null) ...[
                      Text(_signInError!,
                          style: const TextStyle(
                              color: Color(0xFFFFB8B8),
                              fontFamily: 'NotoSansArabic')),
                      const SizedBox(height: 8),
                    ],
                    // Option 2: Google Sign In
                    _OptionButton(
                      icon: Icons.g_mobiledata_rounded,
                      iconSize: 34,
                      title: 'المتابعة بحساب Google',
                      subtitle: 'حفظ التقدم والنتائج واللعب عبر الإنترنت',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                      loading: _isSigningIn,
                      onPressed: () => _handleGoogleSignIn(appState),
                    ),

                    const SizedBox(height: 10),

                    // Secondary actions
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _openOtherLoginOptions,
                          child: const Text(
                            'خيارات تسجيل أخرى',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'استمرار كزائر',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dismissal stays visible while the larger presenter and actions scroll.
class _GuideDialogBody extends StatelessWidget {
  const _GuideDialogBody({required this.child, required this.closeKey});

  final Widget child;
  final Key closeKey;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: closeKey,
                tooltip: 'إغلاق والعودة إلى الساحة',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xF00D1B31),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      );
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onPressed,
    this.iconSize = 24,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onPressed;
  final double iconSize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: iconSize),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

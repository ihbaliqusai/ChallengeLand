import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../models/campaign_stage.dart';
import '../../../services/campaign_result_handler.dart';
import '../../../services/campaign_service.dart';
import '../../../widgets/currency_reward_overlay.dart';

/// Modal dialog that converts guest players into registered users
/// without losing their earned stage progress, stars, coins, or gems.
class SaveGuestProgressDialog extends StatefulWidget {
  const SaveGuestProgressDialog({
    super.key,
    required this.stage,
    required this.submissionResult,
    required this.rawNativeResult,
    required this.onSaved,
  });

  final CampaignStage stage;
  final StageSubmissionResult submissionResult;
  final Map<String, dynamic> rawNativeResult;
  final void Function(StageSubmissionResult savedResult, bool rewardApplied)
      onSaved;

  static Future<void> show(
    BuildContext context, {
    required CampaignStage stage,
    required StageSubmissionResult submissionResult,
    required Map<String, dynamic> rawNativeResult,
    required void Function(StageSubmissionResult savedResult, bool rewardApplied)
        onSaved,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SaveGuestProgressDialog(
        stage: stage,
        submissionResult: submissionResult,
        rawNativeResult: rawNativeResult,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<SaveGuestProgressDialog> createState() =>
      _SaveGuestProgressDialogState();
}

class _SaveGuestProgressDialogState extends State<SaveGuestProgressDialog>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isRegister = true;
  bool _submitting = false;
  String? _errorMessage;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  int get _rewardCoins => widget.submissionResult.rewardCoinsGranted > 0
      ? widget.submissionResult.rewardCoinsGranted
      : (widget.submissionResult.attempt.score > 0 ? 500 : 100);

  int get _rewardGems => widget.submissionResult.rewardGemsGranted > 0
      ? widget.submissionResult.rewardGemsGranted
      : 50;

  int get _stars => widget.submissionResult.attempt.stars;
  int get _score => widget.submissionResult.attempt.score;

  Future<void> _handleGoogleSignIn(AppState appState) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await appState.signInWithGoogle();
      final user = appState.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _errorMessage = 'لم يكتمل تسجيل الدخول عبر Google.';
          });
        }
        return;
      }
      await _commitProgressAndRewards(appState, user.uid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _parseAuthError(e.toString());
      });
    }
  }

  Future<void> _handleEmailSubmit(AppState appState) async {
    if (_submitting) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _errorMessage = 'يرجى إدخال بريد إلكتروني صالح');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (_isRegister && username.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال اسم اللاعب');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      if (_isRegister) {
        await appState.register(email, password, username);
      } else {
        await appState.signIn(email, password);
      }

      final user = appState.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _errorMessage = 'تعذر تسجيل الدخول، حاول مرة أخرى.';
          });
        }
        return;
      }
      await _commitProgressAndRewards(appState, user.uid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _parseAuthError(e.toString());
      });
    }
  }

  Future<void> _commitProgressAndRewards(AppState appState, String uid) async {
    try {
      final campaignService = CampaignService();
      final user = appState.currentUser;
      final displayName =
          (user?.displayName ?? user?.email?.split('@').first ?? '').trim();

      final result = await campaignService.submitStageResult(
        uid: uid,
        stage: widget.stage,
        nativeResult: widget.rawNativeResult,
        displayName: displayName,
        photoUrl: user?.photoURL,
      );

      final rewardApplied = await CampaignResultHandler.applySubmissionReward(
        appState: appState,
        campaignService: campaignService,
        result: result,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      // Show the reward celebration overlay
      showCurrencyRewardOverlay(
        context,
        coins: _rewardCoins,
        gems: _rewardGems,
      );

      widget.onSaved(result, rewardApplied);
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'تم تسجيل الدخول، وجارٍ استكمال حفظ تقدمك.';
      });
    }
  }

  String _parseAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('email-already-in-use')) {
      return 'هذا البريد مسجل مسبقاً، يمكنك تسجيل الدخول بدلاً من إنشاء حساب.';
    }
    if (lower.contains('wrong-password') ||
        lower.contains('invalid-credential')) {
      return 'كلمة المرور أو البريد الإلكتروني غير صحيح.';
    }
    if (lower.contains('user-not-found')) {
      return 'لا يوجد حساب بهذا البريد، اختر "إنشاء حساب جديد".';
    }
    if (lower.contains('weak-password')) {
      return 'كلمة المرور ضعيفة جداً.';
    }
    if (lower.contains('network-request-failed')) {
      return 'تحقق من اتصالك بالإنترنت وحاول مجدداً.';
    }
    return 'حدث خطأ أثناء المصادقة، حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final isCompact = MediaQuery.sizeOf(context).height < 440;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F1A3C),
                  Color(0xFF060B1E),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFACC15).withValues(alpha: 0.45),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 18 : 24,
                vertical: isCompact ? 14 : 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top Header with Pulsing Trophy & Rewards ────────────
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) => Container(
                          width: isCompact ? 48 : 56,
                          height: isCompact ? 48 : 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFACC15).withValues(
                              alpha: 0.14 + _pulseCtrl.value * 0.1,
                            ),
                            border: Border.all(
                              color: const Color(0xFFFACC15).withValues(
                                alpha: 0.4 + _pulseCtrl.value * 0.4,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: child,
                        ),
                        child: const Icon(
                          Icons.military_tech_rounded,
                          color: Color(0xFFFACC15),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إيداع الجوائز وحفظ التقدم 🏆',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'احفظ نجومك وعملاتك بضغطة واحدة وافتح المرحلة التالية!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Spoils Display Chips ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13224E).withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _SpoilBadge(
                          icon: Icons.star_rounded,
                          color: const Color(0xFFFFD700),
                          label: '$_stars نجوم',
                        ),
                        _SpoilBadge(
                          icon: Icons.monetization_on_rounded,
                          color: const Color(0xFFFACC15),
                          label: '+$_rewardCoins ذهب',
                        ),
                        _SpoilBadge(
                          icon: Icons.diamond_rounded,
                          color: const Color(0xFF38BDF8),
                          label: '+$_rewardGems جوهرة',
                        ),
                        _SpoilBadge(
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFFA78BFA),
                          label: '$_score نقطة',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Fast 1-Tap Google Sign-In ───────────────────────────
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => _handleGoogleSignIn(appState),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        side: BorderSide(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.6),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/ui/google.png',
                              width: 22, height: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'المتابعة السريعة بحساب Google',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Divider ─────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'أو تسجيل سريع بالبريد',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Quick Fields ────────────────────────────────────────
                  if (_isRegister) ...[
                    _QuickTextField(
                      controller: _usernameController,
                      label: 'اسم اللاعب',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _QuickTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  _QuickTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    icon: Icons.lock_rounded,
                    obscureText: true,
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ── Primary Action Button ───────────────────────────────
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _handleEmailSubmit(appState),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF1E1B4B),
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(
                        _submitting
                            ? 'جارٍ الحفظ والإيداع...'
                            : (_isRegister
                                ? 'إنشاء حساب وحفظ الجوائز 🎁'
                                : 'تسجيل الدخول وحفظ الجوائز 🎁'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFACC15),
                        foregroundColor: const Color(0xFF1E1B4B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ── Switch between Register / Sign in ────────────────────
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'لديك حساب بالفعل؟ تسجيل الدخول وحفظ التقدم'
                          : 'ليس لديك حساب؟ إنشاء حساب جديد',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpoilBadge extends StatelessWidget {
  const _SpoilBadge({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _QuickTextField extends StatelessWidget {
  const _QuickTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF7DD3FC)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
      ),
    );
  }
}

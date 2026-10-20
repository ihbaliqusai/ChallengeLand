import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../models/player_profile.dart';
import '../services/invite_service.dart';
import '../services/social_service.dart';
import 'friend_stake_selector.dart';

class FriendChallengeModal extends StatefulWidget {
  const FriendChallengeModal({
    super.key,
    this.initialFriendCode,
    this.initialTab = 0,
    this.initialStake = 0,
  });

  final String? initialFriendCode;
  final int initialTab;
  final int initialStake;

  static Future<void> show(
    BuildContext context, {
    String? initialFriendCode,
    int initialTab = 0,
    int initialStake = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (context) => FriendChallengeModal(
        initialFriendCode: initialFriendCode,
        initialTab: initialTab,
        initialStake: initialStake,
      ),
    );
  }

  @override
  State<FriendChallengeModal> createState() => _FriendChallengeModalState();
}

class _FriendChallengeModalState extends State<FriendChallengeModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _friendCodeController = TextEditingController();

  bool _isVerifying = false;
  bool _isLaunching = false;
  int _stakeCoins = 0;
  String? _errorMessage;
  PlayerProfile? _verifiedOpponent;
  Timer? _debounceTimer;
  int _verificationVersion = 0;

  bool _showQrCode = false;
  List<PlayerProfile> _recentOpponents = [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _stakeCoins = widget.initialStake;
    _tabController = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
    if (widget.initialFriendCode != null &&
        widget.initialFriendCode!.isNotEmpty) {
      _friendCodeController.text = widget.initialFriendCode!.toUpperCase();
      _tabController.index = 2; // switch to enter code tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyEnteredCode(_friendCodeController.text);
      });
    } else {
      if (widget.initialTab >= 0 && widget.initialTab < 4) {
        _tabController.index = widget.initialTab;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkClipboardAutoFill();
        _loadRecentOpponents();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendCodeController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentOpponents() async {
    try {
      final inviteService = context.read<InviteService>();
      final list = await inviteService.getRecentOpponents();
      if (mounted) {
        setState(() {
          _recentOpponents = list;
          _loadingRecent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _checkClipboardAutoFill() async {
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (clip?.text == null || clip!.text!.trim().isEmpty || !mounted) return;
      final inviteService = context.read<InviteService>();
      final code = inviteService.extractFriendCode(clip.text!);
      final myCode = context.read<AppState>().friendCode;
      if (code.isNotEmpty &&
          code != myCode &&
          _friendCodeController.text.isEmpty) {
        setState(() {
          _friendCodeController.text = code;
        });
        _verifyEnteredCode(code);
      }
    } catch (_) {}
  }

  void _onCodeChanged(String value) {
    _verificationVersion++;
    _verifiedOpponent = null;
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    _debounceTimer?.cancel();
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) {
      setState(() {
        _verifiedOpponent = null;
        _isVerifying = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      _verifyEnteredCode(trimmed);
    });
  }

  Future<void> _verifyEnteredCode(String rawCode) async {
    final version = ++_verificationVersion;
    final cleanCode =
        rawCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final appState = context.read<AppState>();
    final myCode = appState.friendCode;
    final myUid = appState.user?.uid ?? '';

    if (cleanCode.isEmpty) {
      setState(() {
        _verifiedOpponent = null;
        _isVerifying = false;
      });
      return;
    }

    if (cleanCode == myCode || cleanCode == myUid.toUpperCase()) {
      setState(() {
        _verifiedOpponent = null;
        _errorMessage = 'لا يمكنك تحدي نفسك! أدخل كود صديقك';
        _isVerifying = false;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final inviteService = context.read<InviteService>();
      final profile = await inviteService.verifyFriendCode(
        cleanCode,
        myFriendCode: myCode,
        myUid: myUid,
      );

      if (!mounted ||
          version != _verificationVersion ||
          appState.currentUser?.uid != myUid) {
        return;
      }

      if (profile != null) {
        setState(() {
          _verifiedOpponent = profile;
          _errorMessage = null;
          _isVerifying = false;
        });
      } else {
        setState(() {
          _verifiedOpponent = null;
          _isVerifying = false;
          // Even if not directly found in public_profiles, allow entering
          // if it looks like a valid format, but inform user
          if (cleanCode.length < 4) {
            _errorMessage = 'كود الصديق غير مكتمل';
          } else {
            _errorMessage = 'لم يتم التحقق من وجود اللاعب، تأكد من صحة الكود';
          }
        });
      }
    } catch (e) {
      if (mounted && version == _verificationVersion) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (clip?.text != null && clip!.text!.trim().isNotEmpty && mounted) {
        final inviteService = context.read<InviteService>();
        final code = inviteService.extractFriendCode(clip.text!);
        final extracted =
            code.isNotEmpty ? code : clip.text!.trim().toUpperCase();
        setState(() {
          _friendCodeController.text = extracted;
        });
        HapticFeedback.selectionClick();
        _verifyEnteredCode(extracted);
      }
    } catch (_) {}
  }

  Future<void> _copyMyCode(String code) async {
    if (code.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF34D399), size: 18),
              const SizedBox(width: 8),
              Text('تم نسخ كود التحدي: $code'),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  Future<void> _shareToWhatsApp(String code, String playerName) async {
    if (code.isEmpty) return;
    final message = InviteService.buildFriendInviteShareMessage(
      code: code,
      playerName: playerName,
    );
    try {
      await Share.share(message, subject: 'تحداني في أرض التحدي!');
    } catch (_) {}
  }

  Future<void> _shareGeneral(String code, String playerName) async {
    if (code.isEmpty) return;
    final message = InviteService.buildFriendInviteShareMessage(
      code: code,
      playerName: playerName,
    );
    try {
      await Share.share(message, subject: 'كود التحدي في أرض التحدي');
    } catch (_) {}
  }

  Future<void> _launchChallenge(String targetCode) async {
    if (_isLaunching) return;
    final cleanCode =
        targetCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleanCode.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كود صديقك');
      return;
    }

    final appState = context.read<AppState>();
    if (cleanCode == appState.friendCode) {
      setState(() => _errorMessage = 'لا يمكنك تحدي نفسك!');
      return;
    }

    setState(() => _isLaunching = true);

    try {
      final user = appState.currentUser;
      if (user == null || user.isAnonymous) {
        throw const SocialException('سجّل الدخول لإرسال تحدٍّ.');
      }
      final social = context.read<SocialService>();
      final inviteService = context.read<InviteService>();
      final peer = _verifiedOpponent?.friendCode == cleanCode
          ? _verifiedOpponent!.uid
          : await social.findCode(cleanCode);
      if (_stakeCoins > 0) {
        await social.sendStakedChallenge(user.uid, peer, _stakeCoins);
      } else {
        await social.send(user.uid, peer, challenge: true);
      }
      // Save to recent opponents if we have a verified profile
      if (_verifiedOpponent != null) {
        await inviteService.saveRecentOpponent(_verifiedOpponent!);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'أُرسلت الدعوة. ستبدأ المواجهة بعد قبول الطرف الآخر خلال 30 ثانية.')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLaunching = false;
          _errorMessage = e is SocialException
              ? e.message
              : 'تعذر إرسال الدعوة. تحقق من الاتصال وحاول مجددًا.';
        });
      }
    }
  }

  Future<void> _startRandomMatch() async {
    if (_isLaunching) return;
    final appState = context.read<AppState>();
    if (!appState.isOnline) {
      setState(() {
        _errorMessage = 'يجب توفر اتصال بالإنترنت للعب ضد منافس عشوائي';
      });
      return;
    }
    if (appState.coins < _stakeCoins) {
      setState(() => _errorMessage = 'رصيدك لا يكفي لمبلغ المباراة المختار.');
      return;
    }

    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    try {
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      await appState.openRandomMatch(stakeCoins: _stakeCoins);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLaunching = false;
          _errorMessage = 'تعذر بدء البحث: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myCode = appState.friendCode;
    final myUser = appState.user;
    final playerName = myUser?.displayName ?? 'بطل التحدي';
    final userLevel = appState.level;

    final media = MediaQuery.of(context);
    final isLandscape = media.size.width > media.size.height;
    final dialogWidth = isLandscape ? 680.0 : 420.0;
    final dialogMaxHeight =
        isLandscape ? media.size.height * 0.92 : media.size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogMaxHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF0A0F1D),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────
                _buildHeader(context),

                // ── Tabs Bar ─────────────────────────────────────────
                _buildTabBar(),

                // ── Tab Views ────────────────────────────────────────
                Flexible(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRandomMatchTab(),
                      _buildMyCardTab(myCode, playerName, userLevel),
                      _buildEnterCodeTab(),
                      _buildRecentOpponentsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header Widget ───────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D3A).withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Color(0xFF070E24),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'مركز التحدي والمواجهة (1 ضد 1)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'منافس عشوائي أونلاين، كود الصديق، أو رمز QR',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded,
                color: Colors.white70, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF080D1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
              blurRadius: 8,
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: const [
          Tab(
            iconMargin: EdgeInsets.only(bottom: 2),
            icon: Icon(Icons.flash_on_rounded, size: 18),
            text: 'منافس عشوائي',
          ),
          Tab(
            iconMargin: EdgeInsets.only(bottom: 2),
            icon: Icon(Icons.badge_rounded, size: 18),
            text: 'بطاقة كودي',
          ),
          Tab(
            iconMargin: EdgeInsets.only(bottom: 2),
            icon: Icon(Icons.vpn_key_rounded, size: 18),
            text: 'إدخال كود',
          ),
          Tab(
            iconMargin: EdgeInsets.only(bottom: 2),
            icon: Icon(Icons.history_rounded, size: 18),
            text: 'سجل الخصوم',
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Random Opponent Matchmaking ──────────────────────────────────────

  Widget _buildRandomMatchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero Glowing Matchmaking Radar Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0284C7).withValues(alpha: 0.15),
                  const Color(0xFF1E1B4B).withValues(alpha: 0.4),
                  const Color(0xFF0F172A).withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                // Glowing Animated Radar/Lightning Icon
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0284C7),
                            Color(0xFF2563EB),
                            Color(0xFF7C3AED)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF38BDF8).withValues(alpha: 0.5),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFFFD700),
                        size: 38,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'المواجهة المباشرة (1 ضد 1)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تحدَّ أي لاعب متصل بالإنترنت الآن في جولة سريعة ومثيرة!\nنظام ذكي للبحث الفوري لتفادي الانتظار.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),

                // Feature Highlights Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFeatureChip(Icons.flash_on_rounded, 'بحث فوري',
                        const Color(0xFFFFD700)),
                    const SizedBox(width: 8),
                    _buildFeatureChip(Icons.military_tech_rounded,
                        'نقاط وتصنيف', const Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    _buildFeatureChip(Icons.smart_toy_rounded, 'خصم متكافئ',
                        const Color(0xFF34D399)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Error indicator if any
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Big Launch Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0284C7),
                  Color(0xFF2563EB),
                  Color(0xFF7C3AED)
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isLaunching ? null : _startRandomMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isLaunching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded,
                      size: 24, color: Color(0xFFFFD700)),
              label: Text(
                _isLaunching
                    ? 'جاري بدء البحث...'
                    : 'ابدأ البحث عن منافس الآن ⚡',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Shortcut to friend challenge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'تريد تحدي صديق محدد؟',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: const Text(
                  'أدخل كود صديقك 🔑',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: My Challenge Card ────────────────────────────────────────────────

  Widget _buildMyCardTab(String myCode, String playerName, int userLevel) {
    final appState = context.watch<AppState>();
    final character = appState.selectedCharacter;
    final photoUrl = appState.user?.photoURL;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── VIP Challenger Pass ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF131D38),
                  Color(0xFF090E21),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Gold Foil Ribbon
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD700).withValues(alpha: 0.25),
                        const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(19)),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        color: Color(0xFFFFD700),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'بطاقة التحدي الرسمية • OFFICIAL CHALLENGER PASS',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'جاهز للمواجهة',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Player Info & Avatar Row
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Avatar with Level Badge
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  character.color.withValues(alpha: 0.35),
                                  const Color(0xFF0F172A),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFFFD700),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: ClipOval(
                              child: photoUrl != null
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        character.asset,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Image.asset(
                                      character.asset,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFF59E0B),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              'Lv.$userLevel',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        character.color.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'شخصية: ${character.nameAr}',
                                    style: TextStyle(
                                      color: character.color,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '• 1 ضد 1',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // QR Toggle button
                      IconButton.filledTonal(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showQrCode = !_showQrCode);
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: _showQrCode
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF1E293B),
                          foregroundColor: _showQrCode
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 22),
                        tooltip: _showQrCode ? 'إخفاء الرمز' : 'عرض رمز QR',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── QR Code Display Card (Expandable) ─────────────────────────────
          if (_showQrCode && myCode.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'امسح الرمز بكاميرا الهاتف للانضمام مباشرة',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: QrImageView(
                      data: 'CL:$myCode',
                      version: QrVersions.auto,
                      size: 140.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'كود التحدي: $myCode',
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

          // ── Stylized Challenge Code Card ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF070D1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.55),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'كود التحدي الخاص بك',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        myCode.isNotEmpty ? myCode : '---',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      myCode.isNotEmpty ? () => _copyMyCode(myCode) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'نسخ الكود',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Quick Share Buttons Row ───────────────────────────────────────
          Row(
            children: [
              // WhatsApp Direct Share
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF25D366),
                        Color(0xFF128C7E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: myCode.isNotEmpty
                        ? () => _shareToWhatsApp(myCode, playerName)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: const Text(
                      'دعوة عبر واتساب',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Full Share
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0284C7),
                        Color(0xFF0369A1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: myCode.isNotEmpty
                        ? () => _shareGeneral(myCode, playerName)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 17),
                    label: const Text(
                      'مشاركة الكود',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Quick Info Note ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B142D).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFD700),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'عند نسخ صديقك للكود وفتح اللعبة، سيظهر له التحدي تلقائياً للبدء فوراً دون عناء الكتابة!',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Quick Match against random opponent banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1E3A).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لا تملك كود صديق؟',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'العب فوراً ضد منافس عشوائي أونلاين',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _startRandomMatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'بحث عشوائي ⚡',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Enter Code & Live Preview ────────────────────────────────────────

  Widget _buildEnterCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'أدخل كود صديقك هنا...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF080E24),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFFD700),
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: _isVerifying
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onCodeChanged,
                  onSubmitted:
                      _stakeCoins == 0 ? (val) => _launchChallenge(val) : null,
                ),
              ),
              const SizedBox(width: 8),
              // Paste Button
              ElevatedButton.icon(
                onPressed: _pasteFromClipboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('لصق',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          // Error indicator
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFF87171), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Live Opponent Preview Card
          if (_verifiedOpponent != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F264A).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF38BDF8), width: 1.5),
                      image: const DecorationImage(
                        image: AssetImage('assets/ui/user.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _verifiedOpponent!.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF38BDF8),
                              size: 16,
                            ),
                          ],
                        ),
                        Text(
                          'الانتصارات: ${_verifiedOpponent!.wins} • النقاط: ${_verifiedOpponent!.totalScore}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              const Color(0xFF34D399).withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'جاهز للتحدي ⚔️',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          FriendStakeSelector(
            amount: _stakeCoins,
            enabled: !_isLaunching,
            onChanged: (amount) => setState(() => _stakeCoins = amount),
          ),
          const SizedBox(height: 14),

          // Start Challenge Button
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isLaunching
                  ? null
                  : () => _launchChallenge(_friendCodeController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: const Color(0xFF0B1437),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isLaunching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0B1437),
                      ),
                    )
                  : const Icon(Icons.flash_on_rounded, size: 20),
              label: Text(
                _isLaunching
                    ? 'جارٍ إرسال الدعوة...'
                    : _stakeCoins > 0
                        ? 'إرسال دعوة بـ$_stakeCoins قطعة'
                        : 'إرسال دعوة مواجهة ⚔️',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Or quick match against random opponent
          OutlinedButton.icon(
            onPressed: _isLaunching ? null : _startRandomMatch,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: BorderSide(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text(
              'أو ابحث عن منافس عشوائي أونلاين ⚡',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Recent Opponents ─────────────────────────────────────────────────

  Widget _buildRecentOpponentsTab() {
    if (_loadingRecent) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      );
    }

    if (_recentOpponents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const Icon(Icons.people_outline_rounded,
                    color: Colors.white38, size: 36),
              ),
              const SizedBox(height: 12),
              const Text(
                'لا يوجد خصوم أخيرون حالياً',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'شارك كودك مع أصدقائك أو العب مباريات لتسجيل منافسيك هنا وتحديهم بنقرة واحدة!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _recentOpponents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final opponent = _recentOpponents[index];
        final cleanCode =
            opponent.uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
        final displayCode =
            cleanCode.length > 10 ? cleanCode.substring(0, 10) : cleanCode;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A122A).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/ui/user.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponent.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'كود: $displayCode',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _friendCodeController.text = displayCode;
                  _tabController.index = 2;
                  _verifyEnteredCode(displayCode);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 14),
                label: const Text('تحدي',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}

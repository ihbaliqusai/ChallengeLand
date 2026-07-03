import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../models/game_character.dart';
import '../../services/ad_service.dart';
import '../../services/native_bridge_service.dart';
import '../../widgets/currency_reward_overlay.dart';
import '../character/character_select_screen.dart';

class _CoinItem {
  const _CoinItem({
    required this.label,
    required this.coinAmount,
    required this.gemCost,
    required this.tag,
  });

  final String label;
  final int coinAmount;
  final int gemCost;
  final String tag;
}

const List<_CoinItem> _kCoinItems = <_CoinItem>[
  _CoinItem(label: '1,500', coinAmount: 1500, gemCost: 15, tag: 'سريع'),
  _CoinItem(label: '6,000', coinAmount: 6000, gemCost: 55, tag: 'شائع'),
  _CoinItem(label: '14,000', coinAmount: 14000, gemCost: 120, tag: 'شخصية'),
  _CoinItem(label: '35,000', coinAmount: 35000, gemCost: 290, tag: 'قيمة'),
  _CoinItem(label: '90,000', coinAmount: 90000, gemCost: 700, tag: 'كبير'),
];

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _haptic() async {
    await context.read<AppSettings>().playHaptic();
  }

  Future<void> _openCharacters() async {
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    await _haptic();
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const CharacterSelectScreen()),
    );
    if (!mounted) return;
    await appState.loadCharacterState();
    await appState.loadCurrency();
  }

  Future<void> _watchRewardedAd() async {
    if (_busy) return;
    final adService = context.read<AdService>();
    final native = context.read<NativeBridgeService>();
    final appState = context.read<AppState>();
    await _haptic();

    if (!adService.canWatchAd) {
      final remaining = adService.cooldownRemaining;
      _showSnack(
        adService.watchesLeft == 0
            ? 'وصلت إلى الحد اليومي للإعلانات المكافأة.'
            : 'الإعلان التالي بعد ${_formatDuration(remaining)}.',
        isError: true,
      );
      return;
    }

    setState(() => _busy = true);
    final reward = await adService.showRewardedAd();
    if (!mounted) return;
    setState(() => _busy = false);

    if (reward == null) {
      _showSnack('تعذر تشغيل الإعلان أو تم إغلاقه قبل اكتماله.', isError: true);
      return;
    }

    try {
      await native.grantCurrency(
        coins: reward['coins'] ?? 0,
        gems: reward['gems'] ?? 0,
      );
      await appState.loadCurrency();
    } catch (_) {
      if (!mounted) return;
      _showSnack('اكتمل الإعلان، لكن تعذر تسليم المكافأة الآن.', isError: true);
      return;
    }

    if (!mounted) return;
    showCurrencyRewardOverlay(
      context,
      coins: reward['coins'] ?? 0,
      gems: reward['gems'] ?? 0,
    );
  }

  Future<void> _buyCoins(_CoinItem item) async {
    if (_busy) return;
    final appState = context.read<AppState>();
    final native = context.read<NativeBridgeService>();
    await _haptic();

    if (appState.gems < item.gemCost) {
      _showSnack('رصيد الجواهر غير كاف لهذه الحزمة.', isError: true);
      return;
    }

    final ok = await _confirm(
      'تأكيد التحويل',
      'تحويل ${_compactNumber(item.gemCost)} جوهرة إلى ${item.label} كوين؟',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final success = await native.buyCurrency(
      coinAmount: item.coinAmount,
      gemCost: item.gemCost,
    );
    if (!mounted) return;
    if (success) {
      await appState.loadCurrency();
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (!success) {
      _showSnack('فشلت عملية التحويل.', isError: true);
      return;
    }
    _showSnack('تمت إضافة ${item.label} كوين.');
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF081328),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              content: Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFACC15),
                    foregroundColor: const Color(0xFF111827),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'تأكيد',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor:
            isError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final adService = context.watch<AdService>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF071126),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset('assets/ui/bg_main.png', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      const Color(0xFF030712).withValues(alpha: 0.56),
                      const Color(0xFF071126).withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _Header(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: _StoreDashboard(
                      coins: appState.coins,
                      gems: appState.gems,
                      adService: adService,
                      selectedCharacter: appState.selectedCharacter,
                      unlockedCharacters: CharacterCatalog.all
                          .where(appState.isCharacterUnlocked)
                          .length,
                      busy: _busy,
                      onOpenCharacters: _openCharacters,
                      onWatchAd: _watchRewardedAd,
                      onBuyCoins: _buyCoins,
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.16),
                    child: const Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFFFACC15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoreDashboard extends StatelessWidget {
  const _StoreDashboard({
    required this.coins,
    required this.gems,
    required this.adService,
    required this.selectedCharacter,
    required this.unlockedCharacters,
    required this.busy,
    required this.onOpenCharacters,
    required this.onWatchAd,
    required this.onBuyCoins,
  });

  final int coins;
  final int gems;
  final AdService adService;
  final GameCharacter selectedCharacter;
  final int unlockedCharacters;
  final bool busy;
  final VoidCallback onOpenCharacters;
  final VoidCallback onWatchAd;
  final void Function(_CoinItem item) onBuyCoins;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 760 ? 12.0 : 16.0;
        final gap = constraints.maxWidth < 760 ? 10.0 : 12.0;
        final coinColumns = constraints.maxWidth >= 1120
            ? 5
            : constraints.maxWidth >= 820
                ? 3
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                2,
                horizontalPadding,
                14,
              ),
              sliver: SliverToBoxAdapter(
                child: _StoreOverview(
                  coins: coins,
                  gems: gems,
                  adService: adService,
                  selectedCharacter: selectedCharacter,
                  unlockedCharacters: unlockedCharacters,
                  busy: busy,
                  onOpenCharacters: onOpenCharacters,
                  onWatchAd: onWatchAd,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                10,
              ),
              sliver: const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.currency_exchange_rounded,
                  title: 'تحويل الجواهر',
                  subtitle: 'حوّل الجواهر إلى كوين لفتح الشخصيات',
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                22,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: coinColumns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  mainAxisExtent: 168,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _kCoinItems[index];
                    return _CoinPackCard(
                      item: item,
                      affordable: gems >= item.gemCost,
                      busy: busy,
                      onTap: () => onBuyCoins(item),
                    );
                  },
                  childCount: _kCoinItems.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'المتجر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'الشخصيات، الرصيد، وتحويل الجواهر',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'رجوع',
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreOverview extends StatelessWidget {
  const _StoreOverview({
    required this.coins,
    required this.gems,
    required this.adService,
    required this.selectedCharacter,
    required this.unlockedCharacters,
    required this.busy,
    required this.onOpenCharacters,
    required this.onWatchAd,
  });

  final int coins;
  final int gems;
  final AdService adService;
  final GameCharacter selectedCharacter;
  final int unlockedCharacters;
  final bool busy;
  final VoidCallback onOpenCharacters;
  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final wallet = _WalletPanel(coins: coins, gems: gems);
        final characters = _CharacterStorePanel(
          character: selectedCharacter,
          unlockedCharacters: unlockedCharacters,
          onOpen: onOpenCharacters,
        );
        final ads = _AdRewardPanel(
          adService: adService,
          busy: busy,
          onWatchAd: onWatchAd,
        );

        if (!wide) {
          return Column(
            children: <Widget>[
              wallet,
              const SizedBox(height: 10),
              characters,
              const SizedBox(height: 10),
              ads,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 5, child: wallet),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: characters),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: ads),
            ],
          ),
        );
      },
    );
  }
}

class _WalletPanel extends StatelessWidget {
  const _WalletPanel({
    required this.coins,
    required this.gems,
  });

  final int coins;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(accent: const Color(0xFFFACC15)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFFACC15),
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'رصيدك',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'الرصيد المستخدم لفتح الشخصيات',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _BalanceCard(
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFFFACC15),
                  value: _compactNumber(coins),
                  label: 'كوين',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceCard(
                  icon: Icons.diamond_rounded,
                  color: const Color(0xFF38BDF8),
                  value: _compactNumber(gems),
                  label: 'جوهرة',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterStorePanel extends StatelessWidget {
  const _CharacterStorePanel({
    required this.character,
    required this.unlockedCharacters,
    required this.onOpen,
  });

  final GameCharacter character;
  final int unlockedCharacters;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(accent: character.color),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: character.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: character.color.withValues(alpha: 0.38),
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  character.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    color: character.color,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'الشخصيات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'المختار: ${character.nameAr}',
                      style: TextStyle(
                        color: character.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _TagPill(
                text: '$unlockedCharacters/${CharacterCatalog.all.length}',
                color: character.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            character.tagAr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.groups_rounded,
            label: 'فتح وتغيير الشخصيات',
            color: const Color(0xFF4338CA),
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}

class _AdRewardPanel extends StatelessWidget {
  const _AdRewardPanel({
    required this.adService,
    required this.busy,
    required this.onWatchAd,
  });

  final AdService adService;
  final bool busy;
  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    final progress =
        (adService.watchesToday / AdService.maxDailyWatches).clamp(0.0, 1.0);
    final canWatch = adService.canWatchAd && !busy;
    final status = adService.watchesLeft == 0
        ? 'اكتمل حد الإعلانات اليومي'
        : adService.cooldownRemaining > Duration.zero
            ? 'الإعلان التالي بعد ${_formatDuration(adService.cooldownRemaining)}'
            : '${adService.watchesLeft} إعلانات متاحة اليوم';

    return Container(
      decoration: _panelDecoration(accent: const Color(0xFF34D399)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.ondemand_video_rounded,
                  color: Color(0xFF34D399),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'مكافأة الإعلان',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.09),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF34D399),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: Icons.play_circle_fill_rounded,
            label: 'شاهد إعلاناً',
            color: const Color(0xFF166534),
            onTap: canWatch ? onWatchAd : null,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          height: 2,
          width: 76,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

class _CoinPackCard extends StatelessWidget {
  const _CoinPackCard({
    required this.item,
    required this.affordable,
    required this.busy,
    required this.onTap,
  });

  final _CoinItem item;
  final bool affordable;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = affordable && !busy;
    final rate = (item.coinAmount / item.gemCost).round();

    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: Container(
        decoration: _panelDecoration(
          accent:
              affordable ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.30),
                    ),
                  ),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFFACC15),
                    size: 24,
                  ),
                ),
                const Spacer(),
                _TagPill(text: item.tag, color: const Color(0xFF38BDF8)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${item.label} كوين',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Text(
              '${_compactNumber(item.gemCost)} جوهرة  •  $rate كوين لكل جوهرة',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            _ActionButton(
              icon: enabled ? Icons.add_rounded : Icons.lock_rounded,
              label: enabled ? 'تحويل الآن' : 'جواهر غير كافية',
              color:
                  enabled ? const Color(0xFF0369A1) : const Color(0xFF374151),
              onTap: enabled ? onTap : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.27)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.48 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration({required Color accent}) {
  return BoxDecoration(
    color: const Color(0xFF081328).withValues(alpha: 0.84),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: accent.withValues(alpha: 0.27)),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.20),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _compactNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs >= 1000000) {
    final number = abs / 1000000;
    return '$sign${number.toStringAsFixed(number >= 10 ? 0 : 1)}M';
  }
  if (abs >= 1000) {
    final number = abs / 1000;
    return '$sign${number.toStringAsFixed(number >= 10 ? 0 : 1)}K';
  }
  return value.toString();
}

String _formatDuration(Duration duration) {
  if (duration <= Duration.zero) return 'الآن';
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes';
  }
  return '$minutes:$seconds';
}

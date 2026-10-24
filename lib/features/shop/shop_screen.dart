import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../home/widgets/game_page_shell.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GamePageShell(
      selectedIndex: 0,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        children: const [
          GameSectionTitle(
            AppStrings.rewardsTitle,
            subtitle: AppStrings.rewardsSubtitle,
          ),
          SizedBox(height: 16),
          _DailyRewardBanner(),
          SizedBox(height: 14),
          _PagerDots(),
          SizedBox(height: 22),
          _OfferGrid(),
          SizedBox(height: 30),
          GameSectionTitle(AppStrings.gameplayCoins),
          SizedBox(height: 18),
          _CoinGrid(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DailyRewardBanner extends StatelessWidget {
  const _DailyRewardBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE92DFF), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 170,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0AE7FF), Color(0xFF008AD8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _BeachBall(),
                        SizedBox(height: 8),
                        Text(
                          AppStrings.funBundle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            height: 0.92,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 2,
                                offset: Offset(2, 3),
                              ),
                              Shadow(
                                color: Color(0xFFFFE700),
                                blurRadius: 0,
                                offset: Offset(1, -1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(flex: 7, child: _BundleItems()),
              ],
            ),
          ),
          StoreButton(label: AppStrings.unlockByPlaying, onPressed: () {}),
        ],
      ),
    );
  }
}

class _BundleItems extends StatelessWidget {
  const _BundleItems();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF073A74).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          _BundleCard(icon: Icons.pets_rounded, label: '×١', locked: true),
          _BundleCard(icon: Icons.auto_awesome_rounded, label: ''),
          _BundleCard(icon: Icons.waves_rounded, label: '×١٠', locked: true),
        ],
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.icon,
    required this.label,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: locked
                        ? const [Color(0xFFFFD956), Color(0xFFFF6548)]
                        : const [Color(0xFFEFF9FF), Color(0xFF8AAEC1)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(icon, color: const Color(0xFF4A2149), size: 32),
              ),
              if (locked)
                const Positioned(
                  top: -7,
                  left: -5,
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferGrid extends StatelessWidget {
  const _OfferGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: const [
        _StoreCard(
          icon: Icons.card_giftcard_rounded,
          label: AppStrings.freeReward,
        ),
        _StoreCard(
          icon: Icons.monetization_on_rounded,
          label: AppStrings.inviteFriends,
          topText: '300',
        ),
        _StoreCard(
          icon: Icons.tag_faces_rounded,
          label: AppStrings.playStreak,
          coinLabel: true,
          topText: '×٢',
        ),
      ],
    );
  }
}

class _CoinGrid extends StatelessWidget {
  const _CoinGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 14,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.74,
      children: const [
        _StoreCard(
          icon: Icons.toll_rounded,
          label: AppStrings.earnByPlaying,
          topText: '200',
        ),
        _StoreCard(
          icon: Icons.emoji_events_rounded,
          label: AppStrings.winStreak,
          topText: '600',
        ),
        _StoreCard(
          icon: Icons.local_movies_rounded,
          label: AppStrings.dailyReward,
          topText: '1,350',
          ribbon: AppStrings.activeReward,
        ),
      ],
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.icon,
    required this.label,
    this.topText,
    this.coinLabel = false,
    this.ribbon,
  });

  final IconData icon;
  final String label;
  final String? topText;
  final bool coinLabel;
  final String? ribbon;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFC413F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: const Color(0xFFFFD23D), size: 66),
                if (topText != null)
                  Positioned(
                    top: 10,
                    child: Text(
                      topText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 2,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (ribbon != null)
                  Positioned(
                    right: -3,
                    left: -3,
                    bottom: 4,
                    child: Container(
                      color: const Color(0xFFFF3A9A),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        ribbon!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          StoreButton(
            label: label,
            icon: coinLabel ? Icons.monetization_on_rounded : null,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _PagerDots extends StatelessWidget {
  const _PagerDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == 0 ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _BeachBall extends StatelessWidget {
  const _BeachBall();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.beach_access_rounded, color: Color(0xFFFFE600), size: 44),
        Icon(Icons.pool_rounded, color: Color(0xFFFF596D), size: 44),
      ],
    );
  }
}

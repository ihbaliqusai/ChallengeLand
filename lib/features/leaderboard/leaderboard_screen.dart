import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/leaderboard_provider.dart';
import '../home/widgets/game_page_shell.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _periodIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaderboardProvider>();

    return GamePageShell(
      selectedIndex: 2,
      child: Column(
        children: [
          const SizedBox(height: 24),
          const GameSectionTitle('LEADERBOARDS'),
          const SizedBox(height: 18),
          _PeriodTabs(
            selectedIndex: _periodIndex,
            onSelected: (index) {
              setState(() => _periodIndex = index);
              final period = switch (index) {
                1 => 'week',
                2 => 'all',
                _ => 'today',
              };
              context.read<LeaderboardProvider>().load(period: period);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                    itemBuilder: (context, index) {
                      final entry = provider.entries[index];
                      return _RankCard(
                        rank: entry.rank,
                        name: entry.username,
                        score: entry.score,
                        wins: entry.wins,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: provider.entries.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['TODAY', 'WEEK', 'ALL'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: StoreButton(
                label: labels[index],
                onPressed: () => onSelected(index),
                icon: selected ? Icons.check_rounded : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.rank,
    required this.name,
    required this.score,
    required this.wins,
  });

  final int rank;
  final String name;
  final int score;
  final int wins;

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (rank) {
      1 => const Color(0xFFFFE536),
      2 => const Color(0xFFCFE8FF),
      3 => const Color(0xFFFF9B43),
      _ => const Color(0xFF2BC2FF),
    };
    return Container(
      height: 86,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2EC0FF), Color(0xFF0B6BC8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF073C90), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medalColor,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Color(0xFF16234F),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                Text(
                  '$wins WINS',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFFD93A),
                size: 34,
              ),
              const SizedBox(width: 6),
              Text(
                '$score',
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
            ],
          ),
        ],
      ),
    );
  }
}

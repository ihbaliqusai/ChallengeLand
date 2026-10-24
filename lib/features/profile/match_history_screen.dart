import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/match_history_tile.dart';
import '../../state/profile_provider.dart';

class MatchHistoryScreen extends StatelessWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<ProfileProvider>().history;
    return Scaffold(
      appBar: AppBar(title: const Text('سجل المباريات')),
      body: history.isEmpty
          ? const EmptyState(message: AppStrings.noMatchHistory)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) =>
                  MatchHistoryTile(match: history[index]),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: history.length,
            ),
    );
  }
}

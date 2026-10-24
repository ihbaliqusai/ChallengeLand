import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../state/friends_provider.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<FriendsProvider>().requests;
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الصداقة')),
      body: requests.isEmpty
          ? const EmptyState(message: AppStrings.noFriendRequests)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final request = requests[index];
                return AppCard(
                  child: Row(
                    children: [
                      Expanded(child: Text(request.fromUsername)),
                      IconButton(
                        tooltip: 'قبول',
                        onPressed: () =>
                            context.read<FriendsProvider>().accept(request),
                        icon: const Icon(Icons.check_circle_rounded),
                      ),
                      IconButton(
                        tooltip: 'رفض',
                        onPressed: () =>
                            context.read<FriendsProvider>().reject(request),
                        icon: const Icon(Icons.cancel_rounded),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: requests.length,
            ),
    );
  }
}

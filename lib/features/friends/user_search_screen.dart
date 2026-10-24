import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/friend_tile.dart';
import '../../state/auth_provider.dart';
import '../../state/friends_provider.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('بحث عن لاعب')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppTextField(
                controller: _controller,
                label: 'اسم اللاعب',
                icon: Icons.search_rounded,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'بحث',
                icon: Icons.search_rounded,
                onPressed: () => provider.search(_controller.text),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: provider.searchResults.isEmpty
                    ? const EmptyState(message: 'لا توجد بيانات حاليًا')
                    : ListView.separated(
                        itemBuilder: (context, index) {
                          final user = provider.searchResults[index];
                          return FriendTile(
                            user: user,
                            actionLabel: 'إضافة',
                            onChallenge: () {
                              final me = context.read<AuthProvider>().user;
                              if (me != null) provider.sendRequest(me, user);
                            },
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: provider.searchResults.length,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

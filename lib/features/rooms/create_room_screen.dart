import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/challenge_scaffold.dart';
import '../../state/auth_provider.dart';
import '../../state/room_provider.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _nameController = TextEditingController(text: 'غرفة التحدي');
  final int _questionCount = 10;
  int _maxPlayers = 4;
  int _roundDuration = 60;
  int _totalRounds = 5;
  String _mode = 'quick1v1';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();
    return ChallengeScaffold(
      title: 'إنشاء غرفة',
      subtitle: 'اضبط الجولة ثم شارك الكود مع اللاعبين.',
      children: [
        AppTextField(
          controller: _nameController,
          label: 'اسم الغرفة',
          icon: Icons.meeting_room_rounded,
        ),
        const SizedBox(height: 16),
        _choiceRow(
          'النمط',
          {
            'quick1v1': '1 ضد 1',
            'teams2v2': 'فرق 2v2',
            'teams3v3': 'فرق 3v3',
            'party': 'حفلة',
          },
          _mode,
          (value) => setState(() => _mode = value),
        ),
        _choiceRow(
          'عدد الجولات',
          {3: '3', 5: '5', 7: '7', 10: '10'},
          _totalRounds,
          (value) => setState(() => _totalRounds = value),
        ),
        _choiceRow(
          'مدة الجولة',
          {30: '30ث', 60: '60ث', 90: '90ث', 120: '2د'},
          _roundDuration,
          (value) => setState(() => _roundDuration = value),
        ),
        _choiceRow(
          'اللاعبون',
          {2: '2', 4: '4', 6: '6', 8: '8'},
          _maxPlayers,
          (value) => setState(() => _maxPlayers = value),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'إنشاء الغرفة',
          icon: Icons.add_rounded,
          isLoading: room.isLoading,
          onPressed: () async {
            final user = context.read<AuthProvider>().user;
            if (user == null) return;
            await context.read<RoomProvider>().createRoom(
              host: user,
              name: _nameController.text.trim(),
              mode: _mode,
              questionCount: _questionCount,
              maxPlayers: _maxPlayers,
              roundDuration: _roundDuration,
              totalRounds: _totalRounds,
            );
            if (context.mounted && context.read<RoomProvider>().room != null) {
              Navigator.pushReplacementNamed(context, AppRoutes.roomLobby);
            }
          },
        ),
        if (room.error != null) ...[
          const SizedBox(height: 12),
          Text(room.error!, textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _choiceRow<T>(
    String label,
    Map<T, String> choices,
    T selected,
    ValueChanged<T> onSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: choices.entries.map((entry) {
              return ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == selected,
                onSelected: (_) => onSelected(entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

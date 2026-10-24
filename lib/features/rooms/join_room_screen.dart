import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/challenge_scaffold.dart';
import '../../state/auth_provider.dart';
import '../../state/room_provider.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();
    return Form(
      key: _formKey,
      child: ChallengeScaffold(
        title: 'دخول بكود',
        subtitle: 'اكتب كود الغرفة المكون من 6 خانات.',
        children: [
          AppTextField(
            controller: _codeController,
            label: 'كود الغرفة',
            icon: Icons.key_rounded,
            maxLength: 6,
            validator: Validators.roomCode,
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'انضمام',
            icon: Icons.login_rounded,
            isLoading: room.isLoading,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final user = context.read<AuthProvider>().user;
              if (user == null) return;
              await context.read<RoomProvider>().joinRoom(
                user,
                _codeController.text.trim().toUpperCase(),
              );
              if (context.mounted &&
                  context.read<RoomProvider>().room != null) {
                Navigator.pushReplacementNamed(context, AppRoutes.roomLobby);
              }
            },
          ),
          if (room.error != null) ...[
            const SizedBox(height: 12),
            Text(room.error!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

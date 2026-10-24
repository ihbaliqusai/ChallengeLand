import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/challenge_scaffold.dart';
import '../../state/auth_provider.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Form(
      key: _formKey,
      child: ChallengeScaffold(
        title: AppStrings.chooseUsername,
        subtitle: 'اختر اسمًا واضحًا سيظهر للأصدقاء وفي لوحة الصدارة.',
        children: [
          AppTextField(
            controller: _controller,
            label: 'اسم اللاعب',
            icon: Icons.badge_rounded,
            maxLength: 20,
            validator: Validators.username,
          ),
          const SizedBox(height: 18),
          AppButton(
            label: AppStrings.save,
            icon: Icons.check_rounded,
            isLoading: auth.isLoading,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              await context.read<AuthProvider>().updateUsername(
                _controller.text,
              );
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              }
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../state/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.challengeDark,
              AppColors.challengeNavy,
              AppColors.challengePurple,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo()),
                    const SizedBox(height: 28),
                    Text(
                      AppStrings.appSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.55,
                        color: AppColors.challengeLight,
                      ),
                    ),
                    const SizedBox(height: 34),
                    AppButton(
                      label: AppStrings.loginWithGoogle,
                      icon: Icons.g_mobiledata_rounded,
                      isLoading: auth.isLoading,
                      onPressed: () async {
                        await context.read<AuthProvider>().signInWithGoogle();
                        if (context.mounted &&
                            context.read<AuthProvider>().isAuthenticated) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.home,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: AppStrings.continueAsGuest,
                      icon: Icons.person_rounded,
                      variant: AppButtonVariant.gold,
                      isLoading: auth.isLoading,
                      onPressed: () async {
                        await context.read<AuthProvider>().signInAsGuest();
                        if (context.mounted &&
                            context.read<AuthProvider>().isAuthenticated) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.home,
                          );
                        }
                      },
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        auth.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.challengeRed),
                      ),
                    ],
                    const SizedBox(height: 22),
                    const Text(
                      'الإصدار الأول مجاني بالكامل ولا يحتوي على مدفوعات أو اشتراكات.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

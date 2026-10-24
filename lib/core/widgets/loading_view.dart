import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'جار التحميل...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class FullScreenLoadingView extends StatelessWidget {
  const FullScreenLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: LoadingView(message: AppStrings.noData));
  }
}

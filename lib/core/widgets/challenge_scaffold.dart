import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'page_header.dart';

class ChallengeScaffold extends StatelessWidget {
  const ChallengeScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.scrollable = true,
    this.bottomNavigationBar,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool scrollable;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      bottomNavigationBar: bottomNavigationBar,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.challengeDark, AppColors.challengeNavy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: scrollable
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      PageHeader(title: title, subtitle: subtitle),
                      content,
                    ],
                  ),
                )
              : Column(
                  children: [
                    PageHeader(title: title, subtitle: subtitle),
                    Expanded(child: content),
                  ],
                ),
        ),
      ),
    );
  }
}

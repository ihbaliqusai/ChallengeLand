import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/category_card.dart';
import '../../core/widgets/challenge_scaffold.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../models/category.dart';
import '../../services/mock_data_service.dart';
import '../../state/auth_provider.dart';
import '../../state/game_provider.dart';

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  late final Future<List<Category>> _categories = MockDataService()
      .getSampleCategories();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: _categories,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        if (snapshot.hasError) {
          return Scaffold(body: ErrorView(message: snapshot.error.toString()));
        }
        final categories = snapshot.data ?? const [];
        return ChallengeScaffold(
          title: 'اختر الفئة',
          subtitle: 'ابدأ جولة مركزة في فئتك المفضلة.',
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 520;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wide ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.08,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return CategoryCard(
                      category: category,
                      onTap: () async {
                        final user = context.read<AuthProvider>().user;
                        if (user == null) return;
                        await context.read<GameProvider>().startGame(
                          player: user,
                          mode: 'categories_points',
                          categoryId: category.id,
                        );
                        if (context.mounted) {
                          Navigator.pushNamed(context, AppRoutes.question);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

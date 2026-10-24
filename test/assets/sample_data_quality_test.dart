import 'dart:convert';
import 'dart:io';

import 'package:challenge_land/models/category.dart';
import 'package:challenge_land/models/question.dart';
import 'package:challenge_land/services/mock_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sample data quality', () {
    late List<Category> categories;
    late List<Question> questions;

    setUpAll(() {
      final categoriesJson =
          jsonDecode(
                File(
                  'assets/sample_data/sample_categories.json',
                ).readAsStringSync(),
              )
              as List<dynamic>;
      final questionsJson =
          jsonDecode(
                File(
                  'assets/sample_data/sample_questions.json',
                ).readAsStringSync(),
              )
              as List<dynamic>;

      categories = categoriesJson
          .whereType<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList(growable: false);
      questions = questionsJson
          .whereType<Map<String, dynamic>>()
          .map(Question.fromJson)
          .toList(growable: false);
    });

    test('has the required Arabic MVP categories', () {
      expect(
        categories.map((category) => category.id),
        containsAll(const [
          'general',
          'history',
          'geography',
          'sports',
          'movies',
          'science',
          'islamic',
          'puzzles',
          'games',
          'celebrities',
        ]),
      );
      expect(categories, hasLength(10));
      expect(
        categories.every((category) => category.titleAr.trim().isNotEmpty),
        isTrue,
      );
      expect(categories.every((category) => category.isActive), isTrue);
    });

    test('has at least 100 valid active questions', () {
      expect(questions.length, greaterThanOrEqualTo(100));
      expect(questions.every((question) => question.isActive), isTrue);
    });

    test('uses unique question ids and unique question text', () {
      final ids = questions.map((question) => question.id).toList();
      final texts = questions
          .map((question) => question.questionText.trim())
          .toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(texts.toSet(), hasLength(texts.length));
    });

    test('links every question to an existing category', () {
      final categoryIds = categories.map((category) => category.id).toSet();

      for (final question in questions) {
        expect(
          categoryIds,
          contains(question.categoryId),
          reason: 'Unknown categoryId in ${question.id}',
        );
      }
    });

    test('keeps options unique and contains the correct answer', () {
      for (final question in questions) {
        expect(question.questionText.trim(), isNotEmpty, reason: question.id);
        expect(
          question.options.length,
          greaterThanOrEqualTo(2),
          reason: question.id,
        );
        expect(
          question.options.toSet(),
          hasLength(question.options.length),
          reason: question.id,
        );
        expect(
          question.options,
          contains(question.correctAnswer),
          reason: question.id,
        );
        expect(question.explanation?.trim(), isNotEmpty, reason: question.id);
        expect(
          const {'easy', 'medium', 'hard'},
          contains(question.difficulty),
          reason: question.id,
        );
        expect(question.points, greaterThan(0), reason: question.id);
      }
    });

    test('spreads questions across all categories', () {
      final counts = <String, int>{};
      for (final question in questions) {
        counts.update(
          question.categoryId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }

      for (final category in categories) {
        expect(
          counts[category.id],
          greaterThanOrEqualTo(5),
          reason: category.id,
        );
      }
    });
  });

  testWidgets(
    'MockDataService loads sample questions and categories from assets',
    (tester) async {
      final service = MockDataService();

      final categories = await service.getSampleCategories();
      final questions = await service.getSampleQuestions(limit: 12);

      expect(categories, hasLength(10));
      expect(questions, hasLength(12));
      expect(
        questions.every((question) => question.questionText.trim().isNotEmpty),
        isTrue,
      );
    },
  );
}

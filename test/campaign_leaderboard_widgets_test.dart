import 'package:challenge_land/models/stage_leaderboard_entry.dart';
import 'package:challenge_land/screens/campaign/widgets/stage_leaderboard_row.dart';
import 'package:challenge_land/screens/campaign/widgets/stage_leaderboard_preview.dart';
import 'package:challenge_land/screens/campaign/stage_leaderboard_screen.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final preview in [false, true]) {
    testWidgets(
        'leaderboard shows a load failure and retries (preview: $preview)',
        (tester) async {
      final service = _RetryLeaderboardService();
      final stage = CampaignDefaults.stages().first;
      await tester.pumpWidget(MaterialApp(
        home: preview
            ? Scaffold(
                body: StageLeaderboardPreview(
                    stage: stage, campaignService: service))
            : StageLeaderboardScreen(stage: stage, campaignService: service),
      ));
      await tester.pumpAndSettle();
      expect(find.text('تعذر تحميل الترتيب.'), findsOneWidget);
      expect(find.textContaining('لا توجد نتائج'), findsNothing);
      expect(service.requests, 1);
      service.fail = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(service.requests, 2);
      expect(find.text('تعذر تحميل الترتيب.'), findsNothing);
      expect(find.textContaining('لا توجد نتائج'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final compact in [false, true]) {
    testWidgets(
        'leaderboard row fits a narrow screen with enlarged Arabic text '
        '(compact: $compact)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(18),
              child: StageLeaderboardRow(
                compact: compact,
                rank: 50,
                entry: const StageLeaderboardEntry(
                  uid: 'player',
                  displayName: 'لاعب يختبر ترتيب المراحل على الشاشة الصغيرة',
                  campaignId: 'main_campaign',
                  stageId: 'legacy_stage',
                  score: 1000200,
                  stars: 3,
                  money: 1000000,
                  correctAnswers: 15,
                  timeMs: 60000,
                  usedLifelines: 1,
                  assisted: true,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('1000200'), findsOneWidget);
      expect(find.text('مساعدة'), findsOneWidget);
    });
  }
}

class _RetryLeaderboardService extends CampaignService {
  _RetryLeaderboardService() : super(firestore: FakeFirebaseFirestore());
  bool fail = true;
  int requests = 0;

  @override
  Future<List<StageLeaderboardEntry>> loadStageLeaderboard({
    required String campaignId,
    required String stageId,
    bool pureOnly = false,
    int limit = 50,
    bool propagateErrors = false,
  }) async {
    requests++;
    if (fail) throw StateError('Connection unavailable');
    return [];
  }
}

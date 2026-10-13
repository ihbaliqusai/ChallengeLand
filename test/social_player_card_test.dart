import 'package:challenge_land/widgets/social_player_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = <String, dynamic>{
  'username': 'أحمد',
  'level': 8,
  'trophies': 2400,
};

Widget _page({
  Map<String, dynamic> profile = _profile,
  VoidCallback? onTap,
  bool selected = false,
  bool online = true,
  bool inMatch = false,
  bool loading = false,
  bool profileUnavailable = false,
  double width = 380,
  double textScale = 1,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SocialPlayerCard(
                profile: profile,
                status: 'متصل الآن',
                onTap: onTap ?? () {},
                selected: selected,
                online: online,
                inMatch: inMatch,
                loading: loading,
                profileUnavailable: profileUnavailable,
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('compact player row opens options by tap and keyboard',
      (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_page(onTap: () => taps++));
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('المستوى 8 · متصل الآن'), findsOneWidget);
    expect(find.text('2400'), findsOneWidget);
    expect(find.byTooltip('خيارات أحمد'), findsOneWidget);
    expect(find.bySemanticsLabel('أحمد، المستوى 8 · متصل الآن، 2400 كأس'),
        findsOneWidget);
    expect(tester.getSize(find.byType(SocialPlayerCard)).height,
        inInclusiveRange(76, 84));
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    await tester.tap(find.text('أحمد'));
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('selected player has a gold highlight', (tester) async {
    for (final selected in [false, true]) {
      await tester.pumpWidget(_page(selected: selected));
      final decoration =
          tester.widget<Ink>(find.byType(Ink)).decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color,
          selected ? const Color(0xFFE7AF28) : const Color(0xFF6540A5));
      expect(border.top.width, 2.5);
      final semantics = tester.widget<Semantics>(find
          .descendant(
            of: find.byType(SocialPlayerCard),
            matching: find.byType(Semantics),
          )
          .first);
      expect(semantics.properties.selected, selected);
    }
  });

  testWidgets(
      'status dot distinguishes available, in-match and offline players',
      (tester) async {
    for (final state in [
      (online: true, inMatch: false, color: const Color(0xFF24B778)),
      (online: true, inMatch: true, color: const Color(0xFFF1B52D)),
      (online: false, inMatch: false, color: const Color(0xFF8693A7)),
    ]) {
      await tester
          .pumpWidget(_page(online: state.online, inMatch: state.inMatch));
      final dot = tester
          .widget<Container>(find.byKey(const ValueKey('player-status-dot')));
      expect((dot.decoration! as BoxDecoration).color, state.color);
    }
  });

  testWidgets(
      'loading and failed profiles do not present invented trophy totals',
      (tester) async {
    await tester.pumpWidget(_page(profile: const {}));
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(_page(profile: const {}, loading: true));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('جارٍ تحميل البيانات…'), findsOneWidget);
    await tester.pumpWidget(_page(profileUnavailable: true));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('2400'), findsNothing);
    expect(find.text('تعذر تحميل بيانات اللاعب'), findsOneWidget);
  });

  testWidgets('unsafe avatar URL uses the circular player fallback',
      (tester) async {
    await tester.pumpWidget(_page(profile: const {
      ..._profile,
      'photoUrl': 'http://example.test/avatar.png',
    }));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);
    final avatar = tester.getSize(find.byType(ClipOval));
    expect(avatar.width, avatar.height);
    expect(avatar.width, greaterThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('260 px row adapts to long names and 1.5 text scale',
      (tester) async {
    await tester.pumpWidget(_page(
      width: 260,
      textScale: 1.5,
      profile: const {
        'username': 'لاعب باسم طويل جداً للاختبار مع مزيد من الكلمات',
        'level': 999999,
        'trophies': 2147483647,
      },
    ));
    expect(find.byType(SocialPlayerCard), findsOneWidget);
    expect(tester.getSize(find.byType(SocialPlayerCard)).width, 260);
    expect(
        tester.getSize(find.byType(SocialPlayerCard)).height, greaterThan(84));
    expect(find.text('2147483647'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

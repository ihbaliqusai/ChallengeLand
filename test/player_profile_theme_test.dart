import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_settings.dart';
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/player_rank.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/core/trophy_league.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/screens/home/profile_screen.dart';
import 'package:challenge_land/screens/social/player_profile_screen.dart';
import 'package:challenge_land/services/social_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _exportPreviews =
    bool.fromEnvironment('EXPORT_PROFILE_THEME', defaultValue: false);
const _sampleName = 'أحمد بطل التحدي';
const _sampleCode = 'CHAMPION99';

class _ProfileUser implements User {
  String name = _sampleName;

  @override
  String get uid => 'profile-theme-player';
  @override
  String get displayName => name;
  @override
  String get email => 'private@example.com';
  @override
  String? get photoURL => null;
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileState extends ChangeNotifier implements AppState {
  final account = _ProfileUser();
  final savedNames = <String>[];

  @override
  User get user => account;
  @override
  User get currentUser => account;
  @override
  int get xp => 2000;
  @override
  int get level => PlayerRank.levelForXp(xp);
  @override
  int get xpInCurrentLevel => PlayerRank.xpIntoLevel(xp);
  @override
  int get xpNeededForLevel => PlayerRank.xpNeededForLevel(level);
  @override
  int get trophies => 1234;
  @override
  int get bestTrophies => 1450;
  @override
  String get friendCode => _sampleCode;
  @override
  GameCharacter get selectedCharacter => CharacterCatalog.all.first;
  @override
  Map<String, int> get playerStats => const {
        'gamesPlayed': 20,
        'wins': 12,
        'losses': 4,
        'draws': 4,
        'correctAnswers': 30,
        'wrongAnswers': 10,
        'totalAnswered': 40,
        'onlineWins': 6,
        'winStreak': 3,
        'bestWinStreak': 4,
        'abandoned': 0,
      };
  @override
  Future<void> checkAndAwardXpForGames() async {}
  @override
  Future<void> updateUsername(String name) async {
    savedNames.add(name);
    account.name = name;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentSettings extends ChangeNotifier implements AppSettings {
  @override
  Future<bool> playButtonClick({bool debounced = false}) async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<SocialService> _publicProfileService() async {
  final db = FakeFirebaseFirestore();
  await db.doc('public_profiles/profile-theme-player').set({
    'uid': 'profile-theme-player',
    'username': _sampleName,
    'friendCode': _sampleCode,
    'xp': 2000,
    'trophies': 1234,
    'wins': 12,
    'gamesPlayed': 20,
    'correctAnswers': 30,
    'accuracy': 75,
    'bestWinStreak': 4,
  });
  return SocialService(firestore: db);
}

void _configureView(WidgetTester tester, Size size, {bool safeInsets = false}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  if (safeInsets) {
    tester.view.padding = const FakeViewPadding(left: 20, right: 20, bottom: 8);
    tester.view.viewPadding =
        const FakeViewPadding(left: 20, right: 20, bottom: 8);
  }
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required Widget screen,
  required GlobalKey previewKey,
  required _ProfileState state,
  required SocialService social,
  double textScale = 1,
}) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: state),
      Provider<SocialService>.value(value: social),
    ],
    child: DefaultAssetBundle(
      bundle: SharedAssets.bundle,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: 'Baloo',
          fontFamilyFallback: const ['NotoSansArabic'],
        ),
        builder: (context, child) => RepaintBoundary(
          key: previewKey,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: screen,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _export(
    WidgetTester tester, GlobalKey previewKey, String name) async {
  if (!_exportPreviews) return;
  await tester.runAsync(() async {
    final context = previewKey.currentContext!;
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, context);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/profile-theme-previews');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    for (final font in {
      'Baloo': 'assets/fonts/baloo.ttf',
      'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)
            ..addFont(SharedAssets.bundle.load(font.value)))
          .load();
    }
  });

  setUp(() {
    final previousSettings = AppSettings.instance;
    final settings = _SilentSettings();
    AppSettings.instance = settings;
    AppSettings.resetClickDebounce();
    addTearDown(() {
      AppSettings.instance = previousSettings;
      settings.dispose();
    });
  });

  for (final scenario in [
    (name: '800x360', size: const Size(800, 360), scale: 1.0, safe: true),
    (name: '960x540', size: const Size(960, 540), scale: 1.0, safe: false),
    (
      name: '320x640-large-text',
      size: const Size(320, 640),
      scale: 1.6,
      safe: false
    ),
  ]) {
    for (final own in [true, false]) {
      final kind = own ? 'own' : 'public';
      testWidgets(
          '$kind profile keeps all content reachable at ${scenario.name}',
          (tester) async {
        _configureView(tester, scenario.size, safeInsets: scenario.safe);
        final state = _ProfileState();
        addTearDown(state.dispose);
        final social = await _publicProfileService();
        final key = GlobalKey();
        await _pumpProfile(tester,
            screen: own
                ? const ProfileScreen()
                : const PlayerProfileScreen(playerUid: 'profile-theme-player'),
            previewKey: key,
            state: state,
            social: social,
            textScale: scenario.scale);

        expect(tester.takeException(), isNull);
        expect(find.text(_sampleName), findsOneWidget);
        await _export(tester, key, '$kind-${scenario.name}');

        // The last trophy rule / public statistic must actually be reachable,
        // including when short landscape or larger text forces scrolling.
        final lastContent = own
            ? find.text(TrophyProgression.rules.last.label)
            : find.byKey(const ValueKey('public-stat:أفضل سلسلة'));
        await tester.ensureVisible(lastContent);
        await tester.pumpAndSettle();
        expect(lastContent.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _export(tester, key, '$kind-${scenario.name}-bottom');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
      'own profile can edit and save a name above the landscape keyboard',
      (tester) async {
    _configureView(tester, const Size(800, 360), safeInsets: true);
    final state = _ProfileState();
    addTearDown(state.dispose);
    final key = GlobalKey();
    await _pumpProfile(tester,
        screen: const ProfileScreen(),
        previewKey: key,
        state: state,
        social: await _publicProfileService());
    final edit = find.byTooltip('تعديل الاسم');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('تغيير الاسم'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 170);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ليان بطلة التحدي');
    final save = find.text('حفظ');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _export(tester, key, 'own-edit-name-keyboard-800x360');
    await tester.tap(save);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(state.savedNames, ['ليان بطلة التحدي']);
    expect(find.text('ليان بطلة التحدي'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

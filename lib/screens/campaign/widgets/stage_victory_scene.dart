import 'package:flutter/material.dart';

import '../../../models/campaign_stage.dart';
import '../../../models/game_character.dart';
import '../../../models/stage_attempt.dart';
import '../../../services/campaign_service.dart';
import '../../../services/native_bridge_service.dart';
import '../../../widgets/adaptive_asset_image.dart';
import 'animated_result_stars.dart';

/// The supplied panel and its live contents share the artwork's coordinate space.
class StageVictoryScene extends StatelessWidget {
  const StageVictoryScene({
    super.key,
    required this.stage,
    required this.result,
    required this.playerName,
    required this.onCollect,
    required this.onMap,
    required this.onRetry,
    required this.onDetails,
    this.photoUrl,
    this.gameplayXp = 0,
    this.saving = false,
    this.collected = false,
    this.isDoubled = false,
    this.onRetrySave,
    this.onNext,
    this.nextLabel = 'المرحلة التالية',
  });

  static const designSize = Size(960, 536);
  final CampaignStage stage;
  final StageSubmissionResult result;
  final String playerName;
  final String? photoUrl;
  final int gameplayXp;
  final bool saving, collected, isDoubled;
  final VoidCallback onCollect, onMap, onRetry, onDetails;
  final VoidCallback? onRetrySave, onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final summary = VictoryScoreSummary(stage: stage, attempt: result.attempt);
    final coins = result.rewardCoinsGranted * (isDoubled ? 2 : 1);
    final gems = result.rewardGemsGranted * (isDoubled ? 2 : 1);
    final xp = result.rewardXpGranted + gameplayXp;
    final rewards = <Widget>[
      if (coins > 0)
        _RewardAmount(
          amount: '+$coins',
          color: const Color(0xFFFFD34C),
          asset: 'assets/home/coins.webp',
          semanticLabel: '$coins عملة',
        ),
      if (gems > 0)
        _RewardAmount(
          amount: '+$gems',
          color: const Color(0xFF76E9FF),
          asset: 'assets/home/gems.webp',
          semanticLabel: '$gems جوهرة',
        ),
      if (xp > 0)
        _RewardAmount(
          amount: '+$xp',
          color: const Color(0xFFEA8EFF),
          semanticLabel: '$xp نقطة خبرة',
        ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/campaign/ui/victory_background.jpg',
          key: const ValueKey('victory-background'),
          fit: BoxFit.cover,
          cacheWidth: 1920,
          excludeFromSemantics: true,
        ),
        SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(
                size: designSize,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/campaign/ui/victory_panel.png',
                          fit: BoxFit.fill,
                          cacheWidth: 1920,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const Positioned(
                        left: 328,
                        top: 142,
                        width: 304,
                        height: 90,
                        child: _VictoryRibbon(),
                      ),
                      Positioned(
                        left: 364,
                        top: 60,
                        width: 232,
                        height: 108,
                        child: FittedBox(
                          child: SizedBox(
                            width: 284,
                            height: 132,
                            child: AnimatedResultStars(
                                stars: result.attempt.stars),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 218,
                        top: 210,
                        width: 117,
                        height: 117,
                        child: ResultPlayerPortrait(photoUrl: photoUrl),
                      ),
                      if (summary.isCompetition)
                        const Positioned(
                          left: 192,
                          top: 194,
                          width: 47,
                          height: 58,
                          child: _FirstPlaceMedal(),
                        ),
                      Positioned(
                        left: 147,
                        top: 340,
                        width: 285,
                        height: 43,
                        child: _GoldText(playerName, fontSize: 31),
                      ),
                      Positioned(
                        left: 507,
                        top: 229,
                        width: 303,
                        height: 57,
                        child: _ScoreRow(
                          name: summary.playerLabel ?? playerName,
                          score: summary.playerScore,
                          gold: true,
                          avatar: ResultPlayerPortrait(photoUrl: photoUrl),
                        ),
                      ),
                      Positioned(
                        left: 509,
                        top: 299,
                        width: 301,
                        height: 42,
                        child: _ScoreRow(
                          name: summary.otherName,
                          score: summary.otherScore,
                          gold: false,
                          avatar: Icon(
                            summary.isCompetition
                                ? Icons.person_rounded
                                : Icons.flag_rounded,
                            color: const Color(0xFFE1DAF7),
                            size: 27,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 519,
                        top: 371,
                        width: 288,
                        height: 55,
                        child: saving
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFFFFD34C), strokeWidth: 2))
                            : rewards.isEmpty
                                ? const Center(
                                    child: Text('مكافآت النجوم محفوظة',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 17)))
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      textDirection: TextDirection.ltr,
                                      children: [
                                        for (var index = 0;
                                            index < rewards.length;
                                            index++) ...[
                                          if (index > 0)
                                            const SizedBox(width: 18),
                                          rewards[index],
                                        ],
                                      ],
                                    ),
                                  ),
                      ),
                      Positioned(
                        left: 508,
                        top: 428,
                        width: 307,
                        height: 17,
                        child: Text(
                          saving
                              ? 'جارٍ الحفظ...'
                              : onRetrySave != null
                                  ? 'احفظ النتيجة لإضافة المكافآت'
                                  : 'المرحلة ${stage.order} · ${summary.unit}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFFDFD5F3), fontSize: 10),
                        ),
                      ),
                      Positioned(
                        left: 340,
                        top: 440,
                        width: 281,
                        height: 76,
                        child: Semantics(
                          button: true,
                          enabled: !saving,
                          label: saving
                              ? 'جارٍ حفظ النتيجة'
                              : collected
                                  ? 'تم جمع المكافآت'
                                  : 'اجمع المكافآت',
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: const ValueKey('victory-collect'),
                              onTap: saving || collected ? null : onCollect,
                              child: saving || collected
                                  ? Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: const Color(0xFFFFD76B),
                                            width: 2),
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF12CBEE),
                                            Color(0xFF0862D9)
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                          child: Text(
                                        saving
                                            ? 'جارٍ حفظ النتيجة...'
                                            : 'تم جمع المكافآت ✓',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900),
                                      )),
                                    )
                                  : const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 447,
                        width: 78,
                        height: 77,
                        child: TextButton(
                          onPressed: onMap,
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero),
                          child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map_rounded,
                                        color: Color(0xFFFFD989), size: 39),
                                    Text('الخريطة',
                                        style: TextStyle(
                                            height: 1.2,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900)),
                                  ])),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: 14,
                        height: 35,
                        child: _SceneAction(
                            label: 'تفاصيل المرحلة',
                            icon: Icons.bar_chart_rounded,
                            onPressed: onDetails),
                      ),
                      Positioned(
                        right: 16,
                        top: 14,
                        height: 35,
                        child: _SceneAction(
                            label: 'تحسين النجوم',
                            icon: Icons.refresh_rounded,
                            onPressed: onRetry),
                      ),
                      if (onRetrySave != null)
                        Positioned(
                          right: 145,
                          top: 14,
                          height: 35,
                          child: _SceneAction(
                              label: 'إعادة حفظ النتيجة',
                              icon: Icons.cloud_upload_rounded,
                              onPressed: onRetrySave!),
                        ),
                      if (onNext != null)
                        Positioned(
                          right: 16,
                          bottom: 14,
                          height: 36,
                          child: _SceneAction(
                              label: nextLabel,
                              icon: Icons.arrow_back_rounded,
                              onPressed: onNext!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A solo board compares against its goal; competitive modes show real scores.
class VictoryScoreSummary {
  VictoryScoreSummary(
      {required CampaignStage stage, required StageAttempt attempt}) {
    final mode = campaignModeFromString(
      attempt.campaignMode.isEmpty
          ? stage.campaignMode.value
          : attempt.campaignMode,
      fallbackType: stage.type,
    );
    playerScore = attempt.score;
    otherScore = stage.boardTargetScore;
    otherName = 'هدف المرحلة';
    if (mode == CampaignMode.teamBattle) {
      isCompetition = true;
      playerLabel = 'فريقك';
      playerScore = attempt.teamScore;
      otherScore = attempt.enemyTeamScore;
      otherName = _name(attempt.teamEnemyName, 'الفريق المنافس');
    } else if (mode == CampaignMode.series) {
      isCompetition = true;
      playerScore = attempt.playerSeriesWins;
      otherScore = attempt.opponentSeriesWins;
      otherName = _name(attempt.opponentName, 'الخصم');
      unit = 'جولات الفوز';
    } else if (stage.isBossStage || mode == CampaignMode.bossBattle) {
      isCompetition = true;
      otherScore = attempt.bossScore;
      otherName = _name(attempt.bossName, stage.bossBotName ?? 'الزعيم');
    } else if (mode == CampaignMode.battle) {
      isCompetition = true;
      otherScore = attempt.opponentScore;
      otherName = _name(attempt.opponentName, 'الخصم');
    } else if (mode == CampaignMode.rival && attempt.targetScore > 0) {
      otherScore = attempt.targetScore;
    }
  }

  late int playerScore, otherScore;
  late String otherName;
  String? playerLabel;
  bool isCompetition = false;
  String unit = 'النقاط';

  static String _name(String? value, String fallback) =>
      value?.trim().isNotEmpty == true ? value!.trim() : fallback;
}

class ResultPlayerPortrait extends StatefulWidget {
  const ResultPlayerPortrait({super.key, this.photoUrl});
  final String? photoUrl;

  @override
  State<ResultPlayerPortrait> createState() => _ResultPlayerPortraitState();
}

class _ResultPlayerPortraitState extends State<ResultPlayerPortrait> {
  late final Future<Map<String, dynamic>> _character =
      NativeBridgeService().getCharacterState();

  @override
  Widget build(BuildContext context) => ClipOval(
        child: ColoredBox(
          color: const Color(0xFFFCDA7A),
          child: widget.photoUrl?.startsWith('https://') == true
              ? Image.network(widget.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _characterPortrait())
              : _characterPortrait(),
        ),
      );

  Widget _characterPortrait() => FutureBuilder<Map<String, dynamic>>(
        future: _character,
        builder: (context, snapshot) {
          final index = (snapshot.data?['selected'] as num?)?.toInt() ?? -1;
          return adaptiveAssetImage(
            CharacterCatalog.byIndex(index < 0 ? 1 : index).asset,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                color: Color(0xFF67448A), size: 52),
          );
        },
      );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(
      {required this.name,
      required this.score,
      required this.gold,
      required this.avatar});
  final String name;
  final int score;
  final bool gold;
  final Widget avatar;

  @override
  Widget build(BuildContext context) => Row(
        textDirection: TextDirection.ltr,
        children: [
          Container(
            width: gold ? 47 : 40,
            height: gold ? 47 : 40,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF77738D),
                border: Border.all(
                    color: gold
                        ? const Color(0xFFFFDC71)
                        : const Color(0xFFB9B6C9),
                    width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 5,
                      offset: Offset(0, 3))
                ]),
            child: avatar,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: gold
                  ? _GoldText(name,
                      fontSize: 25, alignment: Alignment.centerLeft)
                  : Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFC4C0D2),
                          fontSize: 24,
                          fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          SizedBox(
              width: 58,
              child: gold
                  ? _GoldText('$score', fontSize: 38)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('$score',
                          style: const TextStyle(
                              color: Color(0xFFB9B3CA),
                              fontSize: 31,
                              fontWeight: FontWeight.w900)))),
        ],
      );
}

class _RewardAmount extends StatelessWidget {
  const _RewardAmount(
      {required this.amount,
      required this.color,
      required this.semanticLabel,
      this.asset});
  final String amount, semanticLabel;
  final Color color;
  final String? asset;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: Row(textDirection: TextDirection.ltr, children: [
          Text(amount,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  color: color,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(
                        color: Colors.black54,
                        blurRadius: 3,
                        offset: Offset(0, 2))
                  ])),
          const SizedBox(width: 5),
          if (asset != null)
            // The rest of this HUD image contains a sample balance and a shop button.
            ClipOval(
              child: SizedBox.square(
                dimension: 39,
                child: Stack(children: [
                  Positioned(
                    left: -48 / 128 * 39,
                    top: -48 / 128 * 39,
                    width: 769 / 128 * 39,
                    height: 224 / 128 * 39,
                    child: adaptiveAssetImage(asset!,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.stars_rounded, color: color, size: 34)),
                  ),
                ]),
              ),
            )
          else
            Container(
              width: 37,
              height: 37,
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(-0.15),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF4B0FF), width: 2),
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEE8FFF), Color(0xFF952FE0)])),
              child: const Text('XP',
                  style: TextStyle(
                      color: Color(0xFF4F147B),
                      fontSize: 19,
                      fontWeight: FontWeight.w900)),
            ),
        ]),
      );
}

class _GoldText extends StatelessWidget {
  const _GoldText(this.text,
      {required this.fontSize, this.alignment = Alignment.center});
  final String text;
  final double fontSize;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF9CF), Color(0xFFFFD651), Color(0xFFE99A20)],
              stops: [0, .5, 1]).createShader(rect),
          child: Text(text,
              maxLines: 1,
              style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'NotoSansArabic',
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                        color: Color(0xFF7C410C),
                        blurRadius: 2,
                        offset: Offset(0, 2))
                  ])),
        ),
      );
}

class _SceneAction extends StatelessWidget {
  const _SceneAction(
      {required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: FilledButton.styleFrom(
            backgroundColor: const Color(0xDC211640),
            foregroundColor: const Color(0xFFFFE8AB),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            side: const BorderSide(color: Color(0xFF927052)),
            textStyle: const TextStyle(
                fontFamily: 'NotoSansArabic',
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      );
}

class _FirstPlaceMedal extends StatelessWidget {
  const _FirstPlaceMedal();
  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.topCenter, children: [
        const Positioned(
            bottom: 0,
            child: Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFB664EB), size: 49)),
        Container(
            width: 43,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEE98), width: 2),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE88E), Color(0xFFF5AE24)])),
            child: const Text('المركز\nالأول',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF8E430B),
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w900))),
      ]);
}

class _VictoryRibbon extends StatelessWidget {
  const _VictoryRibbon();
  @override
  Widget build(BuildContext context) => const CustomPaint(
        painter: _VictoryRibbonPainter(),
        child: Padding(
            padding: EdgeInsets.fromLTRB(34, 5, 34, 16),
            child: Center(
                child: Text('أنت الفائز!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: Color(0xFF5F157E),
                              blurRadius: 3,
                              offset: Offset(0, 3))
                        ])))),
      );
}

class _VictoryRibbonPainter extends CustomPainter {
  const _VictoryRibbonPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tails = Path()
      ..moveTo(0, 17)
      ..lineTo(40, 17)
      ..lineTo(40, 90)
      ..lineTo(0, 90)
      ..lineTo(19, 53)
      ..close()
      ..moveTo(size.width, 17)
      ..lineTo(size.width - 40, 17)
      ..lineTo(size.width - 40, 90)
      ..lineTo(size.width, 90)
      ..lineTo(size.width - 19, 53)
      ..close();
    canvas.drawShadow(tails, Colors.black87, 4, false);
    canvas.drawPath(
        tails,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF4CACFF),
                Color(0xFF9C29E1),
                Color(0xFF5713AB)
              ]).createShader(rect));
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(35, 0, size.width - 70, 72), const Radius.circular(5));
    canvas.drawShadow(Path()..addRRect(body), Colors.black87, 5, false);
    canvas.drawRRect(
        body,
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0xFFAF20DA),
            Color(0xFF752ADD),
            Color(0xFF2AB7F5)
          ]).createShader(rect));
    canvas.drawRRect(
        body.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE99CFF).withValues(alpha: .65));
  }

  @override
  bool shouldRepaint(_VictoryRibbonPainter oldDelegate) => false;
}

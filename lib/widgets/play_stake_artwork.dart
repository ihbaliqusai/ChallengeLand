import 'package:flutter/material.dart';
import 'adaptive_asset_image.dart';

/// The supplied Play artwork rebuilt with live, accessible match controls.
class PlayStakeArtwork extends StatelessWidget {
  const PlayStakeArtwork({
    super.key,
    required this.coins,
    required this.selectedStake,
    required this.stakes,
    required this.difficulty,
    required this.level,
    required this.launching,
    required this.onStakeChanged,
    required this.onRandom,
    required this.onFriend,
    required this.onClose,
  });

  static const asset = 'assets/ui/play_stake_dialog.png';
  static const gold = Color(0xFFFFD776);
  final int coins;
  final int selectedStake;
  final List<int> stakes;
  final String difficulty;
  final String level;
  final bool launching;
  final ValueChanged<int> onStakeChanged;
  final VoidCallback onRandom;
  final VoidCallback onFriend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact =
        media.size.width > media.size.height && media.size.height < 600;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 900 : 590),
          child: Stack(children: [
            Padding(
              padding: EdgeInsets.only(top: compact ? 30 : 46),
              child: _GoldFrame(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      18, compact ? 38 : 66, 18, compact ? 16 : 26),
                  child: compact
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Expanded(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                    _stakeChoices(context),
                                    const SizedBox(height: 14),
                                    _rewardCard(compact: true),
                                  ])),
                              const SizedBox(width: 20),
                              Expanded(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                    _title(compact: true),
                                    const SizedBox(height: 8),
                                    _balance(),
                                    const SizedBox(height: 14),
                                    _actions(),
                                  ])),
                            ])
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              _title(),
                              const SizedBox(height: 16),
                              _balance(),
                              const SizedBox(height: 24),
                              _stakeChoices(context),
                              const SizedBox(height: 20),
                              _rewardCard(),
                              const SizedBox(height: 18),
                              _actions(),
                            ]),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                  child: SizedBox(
                width: compact ? 76 : 112,
                height: compact ? 76 : 112,
                child: const ClipOval(
                    child: _ArtworkSlice(Rect.fromLTRB(550, 20, 834, 307))),
              )),
            ),
            Positioned(
              top: compact ? 22 : 38,
              left: 0,
              child: Semantics(
                button: true,
                label: 'إغلاق',
                child: Tooltip(
                  message: 'إغلاق',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onClose,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: compact ? 48 : 62,
                        height: compact ? 48 : 62,
                        child: const ExcludeSemantics(
                            child: _ArtworkSlice(
                                Rect.fromLTRB(85, 118, 246, 283))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _title({bool compact = false}) => Text(
        'تحدي المواجهة (العب)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Baloo',
          fontFamilyFallback: const ['NotoSansArabic'],
          color: gold,
          fontSize: compact ? 21 : 26,
          fontWeight: FontWeight.w900,
          height: 1.4,
          shadows: const [
            Shadow(color: Color(0xFF6B350D), offset: Offset(0, 3)),
            Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 5)),
          ],
        ),
      );

  Widget _balance() => Center(
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: gold, width: 1.6),
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFBC9241),
                Color(0xFF80501C),
                Color(0xFF57300F)
              ]),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, offset: Offset(0, 4), blurRadius: 5)
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const _Coin(size: 25),
          const SizedBox(width: 8),
          Flexible(
              child: Text('رصيدك الحالي: $coins قطعة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800))),
        ]),
      ));

  Widget _stakeChoices(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('حدد قيمة رهان المباراة (لكل لاعب):',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, area) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
            final columns = largeText || area.maxWidth < 315 ? 3 : 5;
            final width = (area.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final stake in stakes)
                  SizedBox(width: width, child: _stake(stake))
              ],
            );
          }),
        ],
      );

  Widget _actions() => Column(mainAxisSize: MainAxisSize.min, children: [
        _MatchButton(
          title: 'اللعب العشوائي',
          subtitle: 'بحث فوري عن خصم متاح عبر الإنترنت',
          icon: Icons.bolt_rounded,
          colors: const [
            Color(0xFF39BEFF),
            Color(0xFF2075D9),
            Color(0xFF1237A2)
          ],
          edge: const Color(0xFF41BFFF),
          iconColor: gold,
          busy: launching,
          onTap: launching ? null : onRandom,
        ),
        const SizedBox(height: 12),
        _MatchButton(
          title: 'اللعب ضد خصم من اختيارك',
          subtitle: 'اختر منافسك من ساحة اللاعبين وتحدَّه',
          icon: Icons.people_alt_rounded,
          colors: const [
            Color(0xFF24D99B),
            Color(0xFF0B9D73),
            Color(0xFF075B53)
          ],
          edge: const Color(0xFF34E7A9),
          iconColor: const Color(0xFFBEFFE4),
          onTap: launching ? null : onFriend,
        ),
      ]);
  Widget _stake(int stake) {
    final selected = selectedStake == stake;
    final affordable = stake == 0 || coins >= stake;
    return Semantics(
      selected: selected,
      button: true,
      label: stake == 0 ? 'مجانية' : '$stake قطعة',
      hint: affordable ? null : 'الرصيد غير كافٍ',
      child: Tooltip(
        message: affordable
            ? (stake == 0 ? 'مباراة مجانية' : '$stake قطعة لكل لاعب')
            : 'رصيدك لا يكفي لهذا الرهان',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: selected ? gold : const Color(0xFF47649E),
                width: selected ? 2 : 1.5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [
                      Color(0xFFFFE681),
                      Color(0xFFE8AC34),
                      Color(0xFFAA6514)
                    ]
                  : stake == 0
                      ? const [
                          Color(0xFF368EE2),
                          Color(0xFF4F46A3),
                          Color(0xFF49268F)
                        ]
                      : const [
                          Color(0xFF304878),
                          Color(0xFF26355D),
                          Color(0xFF1C294F)
                        ],
            ),
            boxShadow: [
              BoxShadow(
                  color: selected ? const Color(0x66FFC543) : Colors.black45,
                  blurRadius: selected ? 15 : 4,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: launching ? null : () => onStakeChanged(stake),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (stake == 0)
                          const Icon(Icons.confirmation_number_rounded,
                              color: Color(0xFF53D4FF), size: 20)
                        else
                          const _Coin(size: 18),
                        const SizedBox(width: 4),
                        Text(
                          stake == 0 ? 'مجانية' : '$stake',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: selected || affordable
                                  ? Colors.white
                                  : const Color(0xFFB8B9D3),
                              fontWeight: FontWeight.w900,
                              fontSize: 14),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 2),
                          const Icon(Icons.check_rounded,
                              size: 15, color: Color(0xFFFFF4B5)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rewardCard({bool compact = false}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: gold, width: 1.6),
          gradient: const LinearGradient(
              colors: [Color(0xFF393346), Color(0xFF25253D)]),
          boxShadow: const [
            BoxShadow(color: Color(0x33FFCB61), blurRadius: 18)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.emoji_events_rounded, color: gold, size: 27),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedStake == 0
                      ? 'مباراة تدريبية ودية دون رهان'
                      : 'الجائزة للفائز: ${selectedStake * 2} قطعة',
                  style: const TextStyle(
                      color: gold, fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.smart_toy_rounded, color: gold, size: 23),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    compact
                        ? 'الخصم الآلي: $difficulty'
                        : 'الخصم الآلي البديل (عند غياب منافس): $difficulty',
                    style: const TextStyle(
                        color: gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C4B32),
                  border: Border.all(color: const Color(0xFFCE9D42)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('★ $level',
                    style: const TextStyle(
                        color: gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selectedStake == 0
                  ? '✓ يبحث النظام عن لاعب حقيقي أولاً، وإذا لم يتوفر خصم تلعب ضد الكمبيوتر. المباراة المجانية لا تخصم قطعاً من رصيدك.'
                  : '✓ يبحث النظام عن لاعب حقيقي أولاً، وإذا لم يتوفر خصم تلعب ضد الكمبيوتر. الفائز يأخذ القطع والخاسر يخسر الرهان.',
              style: const TextStyle(
                  color: Color(0xFFDDD9E8), fontSize: 12.5, height: 1.65),
            ),
          ],
        ),
      );
}

class _GoldFrame extends StatelessWidget {
  const _GoldFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFFB78C3C)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFEBA0),
              Color(0xFFB77B29),
              Color(0xFFFFD779),
              Color(0xFFFFF1AA),
              Color(0xFFA46523)
            ],
            stops: [0, .28, .52, .75, 1],
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black87, blurRadius: 24, offset: Offset(0, 10))
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF4D265D),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFFFE294)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFB68A50), width: 1.3),
              gradient: const RadialGradient(
                center: Alignment(0, -.35),
                radius: 1.3,
                colors: [
                  Color(0xFF20213F),
                  Color(0xFF181830),
                  Color(0xFF45224D)
                ],
              ),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(25), child: child),
          ),
        ),
      );
}

class _MatchButton extends StatelessWidget {
  const _MatchButton(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.colors,
      required this.edge,
      required this.iconColor,
      required this.onTap,
      this.busy = false});
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color edge;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [edge, colors.last]),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 9, offset: Offset(0, 5))
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(children: [
                  if (busy)
                    const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                  else
                    Icon(icon, color: iconColor, size: 34, shadows: const [
                      Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 2),
                          blurRadius: 2)
                    ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black38,
                                        offset: Offset(0, 2),
                                        blurRadius: 3)
                                  ])),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: const TextStyle(
                                  color: Color(0xFFD5F4FF),
                                  fontSize: 11.5,
                                  height: 1.4)),
                        ]),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_left_rounded,
                      color: Colors.white, size: 30),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _Coin extends StatelessWidget {
  const _Coin({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: const ClipOval(
            child: _ArtworkSlice(Rect.fromLTRB(891, 505, 945, 565))),
      );
}

class _ArtworkSlice extends StatelessWidget {
  const _ArtworkSlice(this.source);
  final Rect source;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: LayoutBuilder(
          builder: (context, area) => Stack(children: [
            Positioned(
              left: -source.left / source.width * area.maxWidth,
              top: -source.top / source.height * area.maxHeight,
              width: 1324 / source.width * area.maxWidth,
              height: 1740 / source.height * area.maxHeight,
              child: adaptiveAssetImage(PlayStakeArtwork.asset,
                  fit: BoxFit.fill, excludeFromSemantics: true),
            ),
          ]),
        ),
      );
}

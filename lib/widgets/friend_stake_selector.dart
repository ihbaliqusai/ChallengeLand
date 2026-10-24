import 'package:flutter/material.dart';

import '../services/social_service.dart';

class FriendStakeSelector extends StatelessWidget {
  const FriendStakeSelector({
    super.key,
    required this.amount,
    required this.onChanged,
    this.allowFree = true,
    this.enabled = true,
  });

  final int amount;
  final ValueChanged<int> onChanged;
  final bool allowFree;
  final bool enabled;

  static Future<int?> choose(BuildContext context, {int initialAmount = 0}) {
    var selected = SocialService.stakeAmounts.contains(initialAmount)
        ? initialAmount
        : SocialService.stakeAmounts.first;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFEA9F),
                          Color(0xFFE5AA38),
                          Color(0xFF9E6D15),
                          Color(0xFFE5AA38),
                          Color(0xFFFFEA9F),
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xCC050212),
                          blurRadius: 36,
                          spreadRadius: 4,
                          offset: Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Color(0x55E5AA38),
                          blurRadius: 18,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(21.5),
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.4),
                          radius: 1.25,
                          colors: [
                            Color(0xFF331662),
                            Color(0xFF1F0D40),
                            Color(0xFF100524),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0x44BE9AFF),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Pinned Header
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFFEA9F),
                                      Color(0xFFE5AA38),
                                      Color(0xFF9E6D15),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x44FFC107),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF280F4D),
                                  ),
                                  child: const Icon(
                                    Icons.sports_esports_rounded,
                                    color: Color(0xFFFFD54F),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تحدي صديقي على قطع',
                                      style: TextStyle(
                                        color: Color(0xFFFFF7DB),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: 0.2,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xAA000000),
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      'تنافس في مواجهة حماسية والفائز يحصد كامل القطع!',
                                      style: TextStyle(
                                        color: Color(0xFFCEBEEA),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(dialogContext),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0x22BE9AFF),
                                      border: Border.all(
                                          color: const Color(0x44BE9AFF)),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Color(0xFFE5D7FA),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Scrollable Selector Body
                          Flexible(
                            child: SingleChildScrollView(
                              child: FriendStakeSelector(
                                amount: selected,
                                allowFree: false,
                                onChanged: (value) =>
                                    setState(() => selected = value),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Pinned Action Buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFE5D7FA),
                                    side: const BorderSide(
                                        color: Color(0x55BE9AFF), width: 1.2),
                                    backgroundColor: const Color(0x22130528),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'رجوع',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFEA79),
                                        Color(0xFFFFC107),
                                        Color(0xFFE68A00),
                                      ],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x66FF9800),
                                        blurRadius: 10,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    key: const ValueKey('sendStakedChallenge'),
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, selected),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: const Color(0xFF2E1500),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.bolt_rounded,
                                          size: 18,
                                          color: Color(0xFF2E1500),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'إرسال دعوة بـ$selected قطعة',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13.5,
                                              color: Color(0xFF2E1500),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DialogCornerBracketPainter(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x28FFD54F),
              ),
              child: const Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFFFFD54F),
                size: 15,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'قيمة التحدي لكل لاعب',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFFFFEFA8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final value in [
              if (allowFree) 0,
              ...SocialService.stakeAmounts,
            ])
              _StakeChip(
                key: ValueKey('friendStake:$value'),
                value: value,
                selected: value == amount,
                enabled: enabled,
                onTap: () => onChanged(value),
              ),
          ],
        ),
        if (amount > 0) ...[
          const SizedBox(height: 10),
          // Prize Pool Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0x35FFB300), Color(0x227C1EC9)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              border: Border.all(
                color: const Color(0x66FFD54F),
                width: 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x44FFD54F),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFD54F),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تدفع $amount قطعة • الفائز يحصل على ${amount * 2} قطعة',
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StatBadge(
                      label: 'رهانك',
                      value: '$amount',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(width: 5),
                    const Text('+',
                        style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    const SizedBox(width: 5),
                    _StatBadge(
                      label: 'المنافس',
                      value: '$amount',
                      icon: Icons.sports_kabaddi_rounded,
                    ),
                    const SizedBox(width: 5),
                    const Text('=',
                        style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    const SizedBox(width: 5),
                    _StatBadge(
                      label: 'الجائزة',
                      value: '${amount * 2}',
                      icon: Icons.military_tech_rounded,
                      highlight: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Guarantees and Rules Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0x22120428),
              border: Border.all(
                color: const Color(0x33BE9AFF),
                width: 1,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 13, color: Color(0xFFCEBEEA)),
                    SizedBox(width: 5),
                    Text(
                      'ضمان النزاهة وحماية الرصيد',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCEBEEA),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'دون مفتاح. تُحجز القطع من الطرفين عند قبول الدعوة. '
                  'التعادل أو خلل المباراة يعيد القطع. الانسحاب بعد البدء يُحسب خسارة.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: Color(0xFFB8A4D8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StakeChip extends StatelessWidget {
  const _StakeChip({
    super.key,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFree = value == 0;
    final label = isFree ? 'مجاني' : '$value قطعة';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6B3312),
                      Color(0xFF451964),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x35230D42),
                      Color(0x2015062C),
                    ],
                  ),
            border: Border.all(
              color:
                  selected ? const Color(0xFFFFD54F) : const Color(0x44BE9AFF),
              width: selected ? 1.6 : 1.0,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x66FFC107),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFree ? Icons.star_rounded : Icons.monetization_on_rounded,
                size: 14,
                color: selected
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFD8B96E),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFFFFF9E6)
                      : const Color(0xFFE4D6F7),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: Color(0xFFFFD54F),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: highlight ? const Color(0x44FFC107) : const Color(0x22BE9AFF),
          border: Border.all(
            color:
                highlight ? const Color(0x88FFD54F) : const Color(0x33BE9AFF),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 10,
                  color: highlight
                      ? const Color(0xFFFFD54F)
                      : const Color(0xFFD4C2F0),
                ),
                const SizedBox(width: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: highlight
                        ? const Color(0xFFFFEFA8)
                        : const Color(0xFFD4C2F0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value 🪙',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: highlight ? const Color(0xFFFFF9E6) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogCornerBracketPainter extends CustomPainter {
  const _DialogCornerBracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD466)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final goldFill = Paint()
      ..color = const Color(0xFFDCA028)
      ..style = PaintingStyle.fill;

    const diamondSize = 13.0;
    const cornerOffset = 18.0;

    void drawCorner(double cx, double cy, double dirX, double dirY) {
      final diamondCenter =
          Offset(cx + dirX * cornerOffset, cy + dirY * cornerOffset);
      final path = Path()
        ..moveTo(diamondCenter.dx, diamondCenter.dy - diamondSize / 2)
        ..lineTo(diamondCenter.dx + diamondSize / 2, diamondCenter.dy)
        ..lineTo(diamondCenter.dx, diamondCenter.dy + diamondSize / 2)
        ..lineTo(diamondCenter.dx - diamondSize / 2, diamondCenter.dy)
        ..close();

      final glowPaint = Paint()
        ..color = const Color(0x66FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);

      final diamondFill = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFE8F7FF), Color(0xFFBCE3F5)],
        ).createShader(
            Rect.fromCircle(center: diamondCenter, radius: diamondSize));
      canvas.drawPath(path, diamondFill);

      final diamondBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(path, diamondBorder);

      final bracketPath = Path();
      bracketPath.moveTo(cx + dirX * 36, cy + dirY * 6);
      bracketPath.quadraticBezierTo(
        cx + dirX * 12,
        cy + dirY * 6,
        cx + dirX * 6,
        cy + dirY * 12,
      );
      bracketPath.lineTo(cx + dirX * 6, cy + dirY * 36);
      canvas.drawPath(bracketPath, goldPaint);

      canvas.drawCircle(Offset(cx + dirX * 38, cy + dirY * 6), 2.0, goldFill);
      canvas.drawCircle(Offset(cx + dirX * 6, cy + dirY * 38), 2.0, goldFill);
    }

    drawCorner(0, 0, 1, 1);
    drawCorner(size.width, 0, -1, 1);
    drawCorner(0, size.height, 1, -1);
    drawCorner(size.width, size.height, -1, -1);

    final flareCenter = Offset(size.width / 2, 0);
    final flareGlow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFBE0), Color(0x88FFD566), Colors.transparent],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: flareCenter, radius: 24));
    canvas.drawCircle(flareCenter, 24, flareGlow);

    final topDiamond = Path()
      ..moveTo(flareCenter.dx, flareCenter.dy - 3)
      ..lineTo(flareCenter.dx + 8, flareCenter.dy)
      ..lineTo(flareCenter.dx, flareCenter.dy + 3)
      ..lineTo(flareCenter.dx - 8, flareCenter.dy)
      ..close();
    canvas.drawPath(topDiamond, Paint()..color = const Color(0xFFFFF9DB));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class BottomGameNav extends StatelessWidget {
  const BottomGameNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final barHeight = compact ? 76.0 : 86.0;
    final liftSpace = compact ? 24.0 : 30.0;
    final totalHeight = safeBottom + barHeight + liftSpace;
    final items = const [
      _NavItem(AppStrings.rewards, Icons.card_giftcard_rounded),
      _NavItem(AppStrings.friends, Icons.diversity_3_rounded),
      _NavItem(AppStrings.home, Icons.home_rounded),
      _NavItem(AppStrings.daily, Icons.sticky_note_2_rounded),
      _NavItem(AppStrings.albums, Icons.menu_book_rounded),
    ];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: safeBottom + barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF24C8FF),
                      Color(0xFF0A8CF0),
                      Color(0xFF064BC8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 18,
                      offset: const Offset(0, -7),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: safeBottom + 6,
              height: barHeight + liftSpace - 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final selected = selectedIndex == index;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _NavButton(
                        item: item,
                        selected: selected,
                        compact: compact,
                        onTap: () => onSelected(index),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedHeight = compact ? 88.0 : 102.0;
    final normalHeight = compact ? 66.0 : 74.0;
    final iconBox = selected
        ? (compact ? 46.0 : 52.0)
        : (compact ? 32.0 : 38.0);

    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(selected ? 14 : 10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: selected ? selectedHeight : normalHeight,
            padding: EdgeInsets.fromLTRB(4, selected ? 8 : 7, 4, 5),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFFFFF4D),
                        Color(0xFFFFE500),
                        Color(0xFFFFA31A),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(selected ? 14 : 10),
              border: selected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : Border.all(color: Colors.transparent),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.26),
                        blurRadius: 0,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFE500).withValues(alpha: 0.28),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: selected
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD26A00),
                            width: 1.5,
                          ),
                        )
                      : null,
                  child: Icon(
                    item.icon,
                    size: selected ? (compact ? 32 : 37) : (compact ? 27 : 31),
                    color: selected
                        ? const Color(0xFF5C2C15)
                        : AppColors.challengeLight,
                    shadows: selected
                        ? null
                        : const [
                            Shadow(
                              color: Color(0xFF01417D),
                              blurRadius: 2,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                ),
                SizedBox(height: selected ? 4 : 3),
                SizedBox(
                  height: compact ? 17 : 19,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected
                            ? AppColors.challengeDark
                            : AppColors.challengeLight,
                        fontWeight: FontWeight.w900,
                        fontSize: selected ? 14 : 12,
                        shadows: selected
                            ? const [
                                Shadow(
                                  color: Colors.white,
                                  blurRadius: 1,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : const [
                                Shadow(
                                  color: Color(0xFF013371),
                                  blurRadius: 2,
                                  offset: Offset(0, 1.5),
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

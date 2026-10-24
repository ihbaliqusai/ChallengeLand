import 'package:flutter/material.dart';

class SideBoostButton extends StatelessWidget {
  const SideBoostButton({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Semantics(
      label: 'فتح اللوحة الجانبية',
      child: Container(
        width: compact ? 46 : 54,
        height: compact ? 58 : 68,
        decoration: BoxDecoration(
          color: const Color(0xFF14121E).withValues(alpha: 0.94),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(999),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(-4, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.chevron_left_rounded,
          color: Colors.white,
          size: compact ? 34 : 42,
        ),
      ),
    );
  }
}

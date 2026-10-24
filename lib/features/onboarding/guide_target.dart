import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../state/guest_guide_provider.dart';
import 'guide_steps.dart';

/// Adds a measurement/tap wrapper to the existing artwork hit area; no artwork
/// or control geometry is changed.
Widget guidedArtworkPosition({
  required String label,
  required Rect rect,
  required Widget child,
}) {
  final target = switch (label) {
    'الملف الشخصي' => GuideTargets.profile,
    'الصدارة' => GuideTargets.leaderboard,
    'المكافآت' => GuideTargets.rewards,
    'الإحصائيات' => GuideTargets.stats,
    'الإنجازات' => GuideTargets.achievements,
    'الإعدادات' => GuideTargets.settings,
    'التحدي الرئيسي' => GuideTargets.main,
    'تحدي جماعي' => GuideTargets.group,
    'تحدي صديق' => GuideTargets.friendMode,
    'أوفلاين' => GuideTargets.offline,
    _ => null,
  };
  return Positioned.fromRect(
    rect: rect,
    child: target == null ? child : GuideTarget(id: target, child: child),
  );
}

bool isGuideVisitor(BuildContext context) {
  final original = context.watch<AppState?>();
  return original?.user == null || original!.user!.isAnonymous;
}

class GuideTarget extends StatefulWidget {
  const GuideTarget({
    super.key,
    required this.id,
    required this.child,
    this.explainToVisitor = true,
  });
  final String id;
  final Widget child;
  final bool explainToVisitor;

  @override
  State<GuideTarget> createState() => _GuideTargetState();
}

class GuideBackScope extends StatelessWidget {
  const GuideBackScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final guide = context.watch<GuestGuideProvider?>();
    final visitor = guide != null && isGuideVisitor(context);
    return PopScope(
      canPop: guide?.expanded != true || !visitor,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) guide?.minimize();
      },
      child: child,
    );
  }
}

class _GuideTargetState extends State<GuideTarget> {
  final _targetKey = GlobalKey();
  GuestGuideProvider? _guide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final guide = context.read<GuestGuideProvider?>();
    if (_guide == guide) return;
    _guide?.unregister(widget.id, _targetKey);
    _guide = guide;
    guide?.register(widget.id, _targetKey);
  }

  @override
  void didUpdateWidget(GuideTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _guide?.unregister(oldWidget.id, _targetKey);
      _guide?.register(widget.id, _targetKey);
    }
  }

  @override
  void dispose() {
    _guide?.unregister(widget.id, _targetKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    final visitor = guide != null && isGuideVisitor(context);
    Widget child = widget.child;
    if (guide != null && visitor && widget.explainToVisitor) {
      void explain() => guide.explain(widget.id);
      child = Semantics(
        button: true,
        onTap: explain,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: explain,
          child: ExcludeFocus(child: AbsorbPointer(child: child)),
        ),
      );
    }
    return KeyedSubtree(key: _targetKey, child: child);
  }
}

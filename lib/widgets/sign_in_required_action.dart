import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../screens/auth/login_bottom_sheet.dart';
import '../features/onboarding/guide_steps.dart';
import '../features/onboarding/guide_target.dart';
import '../state/guest_guide_provider.dart';

/// Keeps lobby controls visible while requiring an account before using them.
class SignInRequiredAction extends StatelessWidget {
  const SignInRequiredAction({
    super.key,
    required this.child,
    this.guideTarget = GuideTargets.ready,
    this.explainToVisitor = true,
  });

  final Widget child;
  final String guideTarget;
  final bool explainToVisitor;

  @override
  Widget build(BuildContext context) {
    if (context.select<AppState, bool>((state) => state.user != null)) {
      return child;
    }
    if (context.read<GuestGuideProvider?>() != null) {
      return GuideTarget(
        id: guideTarget,
        explainToVisitor: explainToVisitor,
        child: child,
      );
    }

    void signIn() => LoginBottomSheet.show(context);

    return MergeSemantics(
      child: Semantics(
        button: true,
        hint: 'يتطلب تسجيل الدخول',
        onTap: signIn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: signIn,
          child: ExcludeFocus(child: AbsorbPointer(child: child)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../screens/auth/login_bottom_sheet.dart';

/// Keeps lobby controls visible and opens the shared guest sign-in sheet.
class SignInRequiredAction extends StatelessWidget {
  const SignInRequiredAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.select<AppState, bool>((state) => state.user != null)) {
      return child;
    }

    void promptLogin() => LoginBottomSheet.show(context);

    return MergeSemantics(
      child: Semantics(
        button: true,
        hint: 'سجّل الدخول للمتابعة',
        onTap: promptLogin,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: promptLogin,
          child: ExcludeFocus(child: AbsorbPointer(child: child)),
        ),
      ),
    );
  }
}

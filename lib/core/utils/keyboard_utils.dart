import 'package:flutter/material.dart';

class KeyboardUtils {
  static void hide(BuildContext context) {
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }
}

/// A wrapper widget to dismiss keyboard when tapping outside
class KeyboardDismissOnTap extends StatelessWidget {
  final Widget child;
  const KeyboardDismissOnTap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => KeyboardUtils.hide(context),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

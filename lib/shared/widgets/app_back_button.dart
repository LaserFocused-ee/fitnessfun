import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A consistent back button that works with GoRouter.
/// Uses context.pop() if possible, otherwise navigates to fallback route.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.fallbackRoute,
    this.onPressed,
  });

  /// Route to navigate to if there's nothing to pop.
  final String? fallbackRoute;

  /// Custom callback instead of default pop behavior.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: onPressed ?? () => _handleBack(context),
    );
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (fallbackRoute != null) {
      context.go(fallbackRoute!);
    } else {
      // Default to home if nothing else
      context.go('/home');
    }
  }
}

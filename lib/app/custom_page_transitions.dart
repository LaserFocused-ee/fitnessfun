import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page that tracks navigation direction for proper animations.
/// The browser back button will animate in reverse direction.
class SlideTransitionPage<T> extends CustomTransitionPage<T> {
  SlideTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Use a slide transition that respects animation direction
            // When animation.status is forward -> push (slide left)
            // When animation.status is reverse -> pop (slide right)
            final isReverse = animation.status == AnimationStatus.reverse;

            // Slide from right to left for push, left to right for pop
            final slideTween = Tween<Offset>(
              begin: isReverse ? const Offset(-0.3, 0) : const Offset(1.0, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));

            final fadeTween = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOut));

            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        );
}

/// No transition page for instant navigation (like tabs, auth redirects).
class NoTransitionPage<T> extends CustomTransitionPage<T> {
  NoTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
        );
}

/// Helper to wrap GoRoute builder with custom page.
Page<T> buildSlideTransitionPage<T>({
  required Widget child,
  LocalKey? key,
  String? name,
}) {
  return SlideTransitionPage<T>(
    key: key,
    name: name,
    child: child,
  );
}

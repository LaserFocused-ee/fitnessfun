import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tracks navigation direction for proper animations on web.
/// Web browser back button doesn't trigger a proper "pop" - it's a URL change.
/// We track the navigation stack depth to detect back vs forward navigation.
class NavigationDirectionTracker {
  static final NavigationDirectionTracker _instance = NavigationDirectionTracker._();
  factory NavigationDirectionTracker() => _instance;
  NavigationDirectionTracker._();

  final List<String> _history = [];
  bool _isGoingBack = false;

  bool get isGoingBack => _isGoingBack;

  void onNavigate(String path) {
    debugPrint('NavTracker: onNavigate($path), history=$_history');

    // Check if we're going back to a previous page in history
    if (_history.length >= 2 && _history[_history.length - 2] == path) {
      _isGoingBack = true;
      _history.removeLast();
      debugPrint('NavTracker: GOING BACK, new history=$_history');
    } else {
      _isGoingBack = false;
      // Avoid duplicates at the end
      if (_history.isEmpty || _history.last != path) {
        _history.add(path);
        debugPrint('NavTracker: GOING FORWARD, new history=$_history');
      } else {
        debugPrint('NavTracker: SAME PAGE, history unchanged');
      }
    }
  }

  void clear() {
    _history.clear();
    _isGoingBack = false;
  }
}

/// Custom page with iOS-style slide transition that respects browser back.
/// Push: new page slides in from right
/// Pop/Back: page slides out to right
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
            final isBack = NavigationDirectionTracker().isGoingBack;
            debugPrint('NavTracker: transitionsBuilder isBack=$isBack');

            // Going back: slide from left to center (page coming back into view)
            // Going forward: slide from right to center (new page entering)
            final begin = isBack ? const Offset(-1, 0) : const Offset(1, 0);
            const end = Offset.zero;

            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: Curves.easeOutCubic));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
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

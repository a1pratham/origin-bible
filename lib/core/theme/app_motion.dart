import 'package:flutter/material.dart';

/// Animation tokens. All animations must go through [resolve] so the app
/// respects the system "remove animations" accessibility setting.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;

  static Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}

/// Fades and slides its child in once when first built.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    required this.child,
    this.offset = 12,
    this.duration = AppMotion.medium,
    super.key,
  });

  final Widget child;
  final double offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.resolve(context, duration),
      curve: AppMotion.curve,
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * offset),
            child: child,
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

/// Wraps [child] in a centered, max-width constrained box — useful for
/// screens that contain their own scrollable (e.g. a ListView/StreamBuilder).
class ResponsivePageFrame extends StatelessWidget {
  const ResponsivePageFrame({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// A scrollable [ListView] that is centered and max-width constrained.
/// Pass [children] directly; the list is non-lazy (suitable for settings
/// screens and profiles with a known, short child count).
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: padding,
          children: children,
        ),
      ),
    );
  }
}
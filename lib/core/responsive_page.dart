import 'package:flutter/material.dart';

const double kDesktopPageWidth = 1120;
const double kComfortPageWidth = 920;

double responsivePageWidth(double availableWidth) {
  if (availableWidth >= 1180) return kDesktopPageWidth;
  if (availableWidth >= 760) return kComfortPageWidth;
  return availableWidth;
}

EdgeInsets responsivePagePadding(double availableWidth) {
  final horizontal = availableWidth >= 1180
      ? 32.0
      : availableWidth >= 760
      ? 24.0
      : 16.0;
  return EdgeInsets.fromLTRB(horizontal, 16, horizontal, 20);
}

class ResponsivePageFrame extends StatelessWidget {
  const ResponsivePageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: responsivePageWidth(constraints.maxWidth),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.controller,
    this.padding,
    this.physics,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        return ListView(
          controller: controller,
          physics: physics,
          padding: padding ?? responsivePagePadding(availableWidth),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: responsivePageWidth(availableWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 230,
    this.maxColumns = 4,
    this.mobileAspectRatio = 1.45,
    this.desktopAspectRatio = 2.35,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double mobileAspectRatio;
  final double desktopAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / minTileWidth).floor().clamp(1, maxColumns);
        final aspectRatio = width >= 900
            ? desktopAspectRatio
            : width >= 640
            ? 1.85
            : mobileAspectRatio;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: children,
        );
      },
    );
  }
}

class ResponsiveContentWrap extends StatelessWidget {
  const ResponsiveContentWrap({
    super.key,
    required this.children,
    this.minTileWidth = 340,
  });

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 760;
        if (!useGrid) {
          return Column(children: children);
        }

        final columns = (constraints.maxWidth / minTileWidth).floor().clamp(2, 3);
        final spacing = 12.0;
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: tileWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

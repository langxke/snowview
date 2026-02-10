import 'package:flutter/material.dart';

Future<T?> showContextMenuAt<T>({
  required BuildContext context,
  required Offset position,
  required WidgetBuilder builder,
  EdgeInsets padding = const EdgeInsets.all(8),
  bool useRootNavigator = true,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push(
    ContextMenuRoute<T>(
      position: position,
      padding: padding,
      builder: builder,
    ),
  );
}

class ContextMenuRoute<T> extends PopupRoute<T> {
  final Offset position;
  final EdgeInsets padding;
  final WidgetBuilder builder;

  ContextMenuRoute({
    required this.position,
    required this.padding,
    required this.builder,
  });

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Material(
      type: MaterialType.transparency,
      child: CustomSingleChildLayout(
        delegate: _ContextMenuLayoutDelegate(
          position: position,
          padding: padding,
          textDirection: Directionality.of(context),
        ),
        child: builder(context),
      ),
    );
  }
}

class ContextMenuSurface extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final BorderRadius borderRadius;
  final double elevation;

  const ContextMenuSurface({
    super.key,
    required this.child,
    this.maxWidth = 260,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.elevation = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      color: Colors.white,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class ContextMenuActionTile<T> extends StatelessWidget {
  final IconData icon;
  final String text;
  final T value;
  final Color? color;

  const ContextMenuActionTile({
    super.key,
    required this.icon,
    required this.text,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

class ContextMenuDivider extends StatelessWidget {
  const ContextMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1);
  }
}

class _ContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset position;
  final EdgeInsets padding;
  final TextDirection textDirection;

  _ContextMenuLayoutDelegate({
    required this.position,
    required this.padding,
    required this.textDirection,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    return BoxConstraints.loose(
      Size(
        (size.width - padding.horizontal).clamp(0.0, size.width),
        (size.height - padding.vertical).clamp(0.0, size.height),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final cursorGap = 2.0;
    var dx = position.dx + cursorGap;
    var dy = position.dy + cursorGap;

    if (dx + childSize.width + padding.right > size.width) {
      dx = position.dx - childSize.width - cursorGap;
    }
    if (dy + childSize.height + padding.bottom > size.height) {
      dy = position.dy - childSize.height - cursorGap;
    }

    final minX = padding.left;
    final maxX = (size.width - childSize.width - padding.right).clamp(minX, double.infinity);
    final minY = padding.top;
    final maxY = (size.height - childSize.height - padding.bottom).clamp(minY, double.infinity);

    dx = dx.clamp(minX, maxX);
    dy = dy.clamp(minY, maxY);

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _ContextMenuLayoutDelegate oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.padding != padding ||
        oldDelegate.textDirection != textDirection;
  }
}

import 'package:flutter/widgets.dart';

import 'package:baseX/Core/app/x_display_scale.dart';

/// Ignores the OS font size and/or display size for [child]; place inside the app's MaterialApp.
class XDisplayLock extends StatelessWidget {
  const XDisplayLock({
    required this.child,
    this.lockTextScale = true,
    this.lockDisplaySize = true,
    this.zoomFactor,
    super.key,
  });

  final Widget child;
  final bool lockTextScale;
  final bool lockDisplaySize;

  /// Fixed factor for tests; when null the live [XDisplayScale] is used.
  final double? zoomFactor;

  @override
  Widget build(BuildContext context) {
    if (!lockDisplaySize) return _build(context, 1.0);
    final fixed = zoomFactor;
    if (fixed != null) return _build(context, fixed);
    return ValueListenableBuilder<double>(
      valueListenable: XDisplayScale.instance,
      builder: (context, factor, _) => _build(context, factor),
    );
  }

  Widget _build(BuildContext context, double factor) {
    final mq = MediaQuery.of(context);
    if (factor == 1.0) {
      if (!lockTextScale) return child;
      return MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.noScaling),
        child: child,
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: mq.size.width * factor,
          height: mq.size.height * factor,
          child: MediaQuery(
            data: mq.copyWith(
              size: mq.size * factor,
              padding: mq.padding * factor,
              viewPadding: mq.viewPadding * factor,
              viewInsets: mq.viewInsets * factor,
              systemGestureInsets: mq.systemGestureInsets * factor,
              devicePixelRatio: mq.devicePixelRatio / factor,
              textScaler: lockTextScale ? TextScaler.noScaling : mq.textScaler,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

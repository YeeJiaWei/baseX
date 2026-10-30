import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Holds the OS display-size zoom factor (current density / default density).
class XDisplayScale extends ValueNotifier<double> with WidgetsBindingObserver {
  XDisplayScale._() : super(1.0);

  /// Shared instance read by [XDisplayLock].
  static final XDisplayScale instance = XDisplayScale._();

  static const MethodChannel _channel = MethodChannel('basex/display');

  bool _observing = false;

  /// Fetches the factor and keeps it fresh on metric changes.
  Future<void> start() async {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    await refresh();
  }

  /// Re-queries the native factor, falling back to 1.0 on any error.
  Future<void> refresh() async {
    double factor = 1.0;
    try {
      final native = await _channel.invokeMethod<double>('zoomFactor');
      if (native != null && native.isFinite && native > 0) factor = native;
    } catch (_) {}
    value = factor;
  }

  @override
  void didChangeMetrics() {
    refresh();
  }
}

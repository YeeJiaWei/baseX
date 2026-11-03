import 'package:baseX/Core/error/x_error_source.dart';
import 'package:flutter/foundation.dart';

/// Describes how an error reached XExceptionHandler.
class XErrorContext {
  const XErrorContext({required this.source, this.details});

  /// An error thrown inside BaseXController.run.
  const XErrorContext.action() : this(source: XErrorSource.action);

  /// An error that escaped to PlatformDispatcher.onError.
  const XErrorContext.uncaught() : this(source: XErrorSource.uncaught);

  /// A Flutter framework error carrying its [FlutterErrorDetails].
  const XErrorContext.widget(FlutterErrorDetails details)
      : this(source: XErrorSource.widget, details: details);

  final XErrorSource source;

  /// Only set when [source] is [XErrorSource.widget].
  final FlutterErrorDetails? details;
}

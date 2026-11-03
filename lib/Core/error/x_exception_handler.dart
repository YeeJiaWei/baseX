import 'dart:async';
import 'dart:ui';

import 'package:baseX/Core/error/x_error_context.dart';
import 'package:baseX/Core/error/x_error_source.dart';
import 'package:baseX/Core/logger/x_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Centralised app-wide error handler: every action, uncaught and widget error flows through [handle]; apps override [report], [render], [shouldReport] and [buildErrorWidget].
class XExceptionHandler {
  XExceptionHandler();

  /// Whether runXApp started Sentry; when true the default [report] sends to it instead of forwarding to the replaced hooks.
  static bool sentryEnabled = false;

  /// The handler [BaseXController.run] hands errors to; replaced by [install].
  static XExceptionHandler instance = XExceptionHandler();

  // The hooks that were set before install(), kept so the defaults can forward to them.
  ErrorCallback? _previousOnError;
  FlutterExceptionHandler? _previousFlutterOnError;
  ErrorWidgetBuilder? _previousErrorWidgetBuilder;

  // The hooks this instance installed, used to never chain to itself.
  ErrorCallback? _installedOnError;
  FlutterExceptionHandler? _installedFlutterOnError;
  ErrorWidgetBuilder? _installedErrorWidgetBuilder;

  /// Takes over PlatformDispatcher.onError, FlutterError.onError and ErrorWidget.builder, remembering the hooks it replaced.
  void install() {
    final onError = PlatformDispatcher.instance.onError;
    if (onError != _installedOnError) _previousOnError = onError;
    final flutterOnError = FlutterError.onError;
    if (flutterOnError != _installedFlutterOnError) {
      _previousFlutterOnError = flutterOnError;
    }
    final errorWidgetBuilder = ErrorWidget.builder;
    if (errorWidgetBuilder != _installedErrorWidgetBuilder) {
      _previousErrorWidgetBuilder = errorWidgetBuilder;
    }

    _installedOnError = (error, stackTrace) {
      handle(error, stackTrace, const XErrorContext.uncaught());
      return true;
    };
    _installedFlutterOnError = (details) => handle(
          details.exception,
          details.stack ?? StackTrace.empty,
          XErrorContext.widget(details),
        );
    _installedErrorWidgetBuilder = buildErrorWidget;

    instance = this;
    PlatformDispatcher.instance.onError = _installedOnError;
    FlutterError.onError = _installedFlutterOnError;
    ErrorWidget.builder = _installedErrorWidgetBuilder!;
  }

  /// Renders the error, then reports it unless shouldReport says it is expected; always returns true.
  bool handle(Object error, StackTrace stackTrace, XErrorContext context) {
    render(error, stackTrace, context);
    if (shouldReport(error)) report(error, stackTrace, context);
    return true;
  }

  /// Shows the error; the default prints Flutter's console dump for widget errors and logs the rest, apps override this to toast.
  void render(Object error, StackTrace stackTrace, XErrorContext context) {
    final details = context.details;
    if (context.source == XErrorSource.widget && details != null) {
      FlutterError.presentError(details);
      return;
    }
    XLogger.error('Unhandled ${context.source.name} error: $error\n$stackTrace');
  }

  /// Whether the error is unexpected and should be reported; false skips [report] for expected failures.
  bool shouldReport(Object error) => true;

  /// Sends the error to Sentry when runXApp started it, else forwards to the hook this handler replaced; apps that report directly override it.
  void report(Object error, StackTrace stackTrace, XErrorContext context) {
    if (sentryEnabled) {
      _reportToSentry(error, stackTrace, context);
      return;
    }
    final details = context.details;
    if (context.source == XErrorSource.widget && details != null) {
      _previousFlutterOnError?.call(details);
      return;
    }
    _previousOnError?.call(error, stackTrace);
  }

  // Not forwarded to the replaced hooks: with Sentry on they are Sentry's own and would double-report.
  void _reportToSentry(
    Object error,
    StackTrace stackTrace,
    XErrorContext context,
  ) {
    final details = context.details;
    unawaited(Sentry.captureException(
      ThrowableMechanism(
        Mechanism(
          type: 'baseX.${context.source.name}',
          handled: context.source == XErrorSource.action,
        ),
        error,
      ),
      stackTrace: stackTrace,
      withScope: (scope) async {
        await scope.setTag('error.source', context.source.name);
        if (details != null) {
          await scope.setContexts('flutter_error', {
            'library': details.library,
            'context': details.context?.toDescription(),
          });
        }
      },
    ));
  }

  /// Builds the widget shown in place of one that failed to build; the default is the previous ErrorWidget.builder.
  Widget buildErrorWidget(FlutterErrorDetails details) {
    final previous = _previousErrorWidgetBuilder;
    if (previous == null) return ErrorWidget(details.exception);
    return previous(details);
  }

  /// Puts back the default instance, for tests.
  @visibleForTesting
  static void resetInstance() => instance = XExceptionHandler();
}

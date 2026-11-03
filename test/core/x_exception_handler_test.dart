import 'dart:ui';

import 'package:baseX/base_x.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingHandler extends XExceptionHandler {
  _RecordingHandler({this.reportable = true});

  final bool reportable;
  final List<Object> rendered = [];
  final List<Object> reported = [];
  final List<XErrorSource> renderedSources = [];

  @override
  void render(Object error, StackTrace stackTrace, XErrorContext context) {
    rendered.add(error);
    renderedSources.add(context.source);
  }

  @override
  bool shouldReport(Object error) => reportable;

  @override
  void report(Object error, StackTrace stackTrace, XErrorContext context) =>
      reported.add(error);
}

class _TestController extends BaseXController<dynamic> {
  Future<void> runAction(Future<void> Function() action) => run(action);
}

void main() {
  late ErrorCallback? savedOnError;
  late FlutterExceptionHandler? savedFlutterOnError;
  late ErrorWidgetBuilder savedErrorWidgetBuilder;

  setUp(() {
    savedOnError = PlatformDispatcher.instance.onError;
    savedFlutterOnError = FlutterError.onError;
    savedErrorWidgetBuilder = ErrorWidget.builder;
    PlatformDispatcher.instance.onError = null;
    FlutterError.onError = null;
    XExceptionHandler.resetInstance();
    XExceptionHandler.sentryEnabled = false;
  });

  tearDown(() {
    XExceptionHandler.sentryEnabled = false;
    PlatformDispatcher.instance.onError = savedOnError;
    FlutterError.onError = savedFlutterOnError;
    ErrorWidget.builder = savedErrorWidgetBuilder;
    XExceptionHandler.resetInstance();
  });

  test('handle renders, reports and returns true', () {
    final handler = _RecordingHandler();

    expect(
      handler.handle('boom', StackTrace.empty, const XErrorContext.action()),
      isTrue,
    );
    expect(handler.rendered, ['boom']);
    expect(handler.reported, ['boom']);
  });

  test('shouldReport false skips report but still renders', () {
    final handler = _RecordingHandler(reportable: false);

    expect(
      handler.handle(
          'expected', StackTrace.empty, const XErrorContext.action()),
      isTrue,
    );
    expect(handler.rendered, ['expected']);
    expect(handler.reported, isEmpty);
  });

  test('default handle does not throw when nothing was chained', () {
    expect(
      XExceptionHandler().handle(
          StateError('boom'), StackTrace.empty, const XErrorContext.uncaught()),
      isTrue,
    );
  });

  test('install routes PlatformDispatcher.onError as uncaught', () {
    final handler = _RecordingHandler()..install();

    final handled =
        PlatformDispatcher.instance.onError!('boom', StackTrace.empty);

    expect(handled, isTrue);
    expect(XExceptionHandler.instance, same(handler));
    expect(handler.renderedSources, [XErrorSource.uncaught]);
  });

  test('default report forwards an uncaught error to the previous onError', () {
    final forwarded = <Object>[];
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      forwarded.add(error);
      return true;
    };
    XExceptionHandler().install();

    PlatformDispatcher.instance.onError!('boom', StackTrace.empty);

    expect(forwarded, ['boom']);
  });

  test('install routes FlutterError.onError as widget with its details', () {
    final handler = _RecordingHandler()..install();
    final details = FlutterErrorDetails(exception: StateError('build'));

    FlutterError.onError!(details);

    expect(handler.rendered.single, isA<StateError>());
    expect(handler.renderedSources, [XErrorSource.widget]);
    expect(handler.reported.single, isA<StateError>());
  });

  test('default report forwards a widget error to the previous FlutterError.onError',
      () {
    final forwarded = <FlutterErrorDetails>[];
    FlutterError.onError = forwarded.add;
    final handler = XExceptionHandler()..install();
    final details = FlutterErrorDetails(exception: StateError('build'));

    handler.report(details.exception, StackTrace.empty,
        XErrorContext.widget(details));

    expect(forwarded, [details]);
  });

  test('default report does not forward to the replaced hooks when Sentry is active',
      () {
    final forwardedUncaught = <Object>[];
    final forwardedWidget = <FlutterErrorDetails>[];
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      forwardedUncaught.add(error);
      return true;
    };
    FlutterError.onError = forwardedWidget.add;
    final handler = XExceptionHandler()..install();
    XExceptionHandler.sentryEnabled = true;
    final details = FlutterErrorDetails(exception: StateError('build'));

    handler.report('boom', StackTrace.empty, const XErrorContext.uncaught());
    handler.report('boom', StackTrace.empty, const XErrorContext.action());
    handler.report(
        details.exception, StackTrace.empty, XErrorContext.widget(details));

    expect(forwardedUncaught, isEmpty);
    expect(forwardedWidget, isEmpty);
  });

  test('install replaces ErrorWidget.builder and the default delegates to the previous one',
      () {
    final delegated = <FlutterErrorDetails>[];
    const marker = SizedBox();
    ErrorWidget.builder = (details) {
      delegated.add(details);
      return marker;
    };
    final handler = XExceptionHandler()..install();
    final details = FlutterErrorDetails(exception: StateError('build'));

    final built = ErrorWidget.builder(details);

    expect(built, same(marker));
    expect(delegated, [details]);
    expect(handler.buildErrorWidget(details), same(marker));
  });

  test('an overriding buildErrorWidget is used by ErrorWidget.builder', () {
    const custom = Placeholder();
    final handler = _CustomWidgetHandler(custom)..install();

    expect(
      ErrorWidget.builder(FlutterErrorDetails(exception: 'x')),
      same(custom),
    );
    expect(handler, isNotNull);
  });

  test('installing twice does not chain the handler to itself', () {
    final forwarded = <Object>[];
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      forwarded.add(error);
      return true;
    };
    final handler = XExceptionHandler()
      ..install()
      ..install();

    PlatformDispatcher.instance.onError!('boom', StackTrace.empty);

    expect(forwarded, ['boom']);
    expect(handler, isNotNull);
  });

  test('BaseXController.run routes a thrown error as an action', () async {
    final handler = _RecordingHandler();
    XExceptionHandler.instance = handler;

    await _TestController().runAction(() async => throw StateError('boom'));

    expect(handler.rendered.single, isA<StateError>());
    expect(handler.renderedSources, [XErrorSource.action]);
  });

  test('BaseXController.run leaves a successful action alone', () async {
    final handler = _RecordingHandler();
    XExceptionHandler.instance = handler;
    var ran = false;

    await _TestController().runAction(() async => ran = true);

    expect(ran, isTrue);
    expect(handler.rendered, isEmpty);
  });
}

class _CustomWidgetHandler extends XExceptionHandler {
  _CustomWidgetHandler(this.widget);

  final Widget widget;

  @override
  Widget buildErrorWidget(FlutterErrorDetails details) => widget;
}

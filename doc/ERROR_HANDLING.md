# Error handling

`XExceptionHandler` is the one place every app error goes through, modelled on
Laravel's exception `Handler`. Failed user actions, uncaught async errors and
widget errors all reach the same `handle`, so reporting, user-facing display
and the fallback widget are each decided in one class.

## The three sources

| `XErrorSource` | Where it comes from | Hook that feeds the handler |
|---|---|---|
| `action` | Anything thrown inside `BaseXController.run` | `run` calls `handle` directly |
| `uncaught` | Uncaught async and platform errors | `PlatformDispatcher.instance.onError` |
| `widget` | Build, layout, paint and gesture errors | `FlutterError.onError` |

Each call carries an `XErrorContext` with the `source` and, for `widget`, the
`FlutterErrorDetails` (`library`, `context`, ...).

## The flow

```
handle(error, stackTrace, context)
  ├─ render(...)                     show / log it
  └─ shouldReport(error)? ─ yes ─▶ report(...)   send it to the crash reporter
```

`handle` always returns `true`. A widget error that fails to build is replaced
on screen by `buildErrorWidget(details)`, installed as `ErrorWidget.builder`.

## Laravel mapping

| Laravel | baseX |
|---|---|
| `App\Exceptions\Handler` | `XExceptionHandler` subclass |
| `report()` | `report` |
| `$dontReport` | `shouldReport` |
| `render()` | `render` |
| Error views (`errors/500.blade.php`) | `buildErrorWidget` |

## baseX defaults

- `render`: widget errors go to `FlutterError.presentError` (Flutter's normal
  console dump); the rest go to `XLogger.error`. baseX has no toast, so
  nothing is shown to the user. Apps override `render` for that.
- `shouldReport`: `true`.
- `report`: forwards to the hook the handler replaced, so a crash reporter set
  up earlier keeps working: `FlutterError.onError` for widget errors,
  `PlatformDispatcher.onError` for the others. An app that reports directly
  overrides `report` and does not call `super`, otherwise the error reaches
  the reporter twice.
- `buildErrorWidget`: the previous `ErrorWidget.builder` (Flutter's red box in
  debug, grey box in release).

## Install

`runXApp` installs the handler just before `runApp`:

```dart
await runXApp(
  exceptionHandler: AppExceptionHandler(), // optional, defaults to the baseX one
  // ...
);
```

`install()` saves the existing `PlatformDispatcher.onError`,
`FlutterError.onError` and `ErrorWidget.builder`, then replaces all three.
Installing the same handler twice never chains it to itself, and
`XExceptionHandler.instance` always points at the installed handler.

Errors raised before `runXApp` (for example during Firebase init) still hit
whatever hooks were set earlier, such as a crash reporter's own integrations.

## Controllers: `run`

`BaseXController.run` wraps a user action and hands anything it throws to
`XExceptionHandler.instance` with the `action` source:

```dart
Future<void> submit() => run(() async {
  await service.submit(form);
  Get.back();
});
```

Keep your own `try`/`on` inside the action for failures the page recovers from
(e.g. show an inline field error); only what you do not catch reaches the handler.

## Override example

Report to the crash reporter directly and toast only for non-widget errors:

```dart
class AppExceptionHandler extends XExceptionHandler {
  @override
  bool shouldReport(Object error) => error is! XError;

  @override
  void report(Object error, StackTrace stackTrace, XErrorContext context) {
    CrashReporter.capture(error, stackTrace, tags: {'source': context.source.name});
  }

  @override
  void render(Object error, StackTrace stackTrace, XErrorContext context) {
    super.render(error, stackTrace, context);
    if (context.source == XErrorSource.widget) return;
    AppToast.error(error is XError ? error.message : 'Something went wrong');
  }

  @override
  Widget buildErrorWidget(FlutterErrorDetails details) =>
      kDebugMode ? super.buildErrorWidget(details) : const AppErrorPlaceholder();
}
```

## `onFailed` is deprecated

The old callback path (`runXApp(onFailed:)`, `GeneralErrorHandle`,
`BaseXController.onFailed` / `onFailedDialog`, and the `onFailed` getter on the
constant) was never reached by the current API service. It is deprecated in
favour of `XExceptionHandler` and still compiles; it will be removed in a later
major release.

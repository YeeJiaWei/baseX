# Change Log

## Unreleased
- New
    - `appEnv`, `isProduction`, `isStaging`, `isDevelopment`: compile-time constants over `--dart-define=APP_ENV`. Branch `EnvironmentResolver.resolve` on them (`if (isProduction) return AppConstantProduction();`) and release builds tree-shake the flavors that were not built, so staging/dev hosts and keys are absent from the production binary. The comparison must read the const directly: any run-time call between the define and the `if` (e.g. a `switch` on `Flavor`) keeps every flavor class reachable. `flavorFromEnv()` still throws on an unknown value
    - `DeviceInfo` (`model`, `osVersion`, `id`, `os`) and `AppInfo` (`name`, `version`, `buildNumber`, `packageName`): plain value holders loaded once by `runXApp` before `runApp` (a failed load is logged and never blocks boot), read via `baseConstant.deviceInfo` / `baseConstant.appInfo`
    - `XExceptionHandler`: a centralised, overridable app-wide error handler (Laravel-style). `runXApp(exceptionHandler:)` installs it over `PlatformDispatcher.onError`, `FlutterError.onError` and `ErrorWidget.builder`, so action (`BaseXController.run`), uncaught and widget errors all flow through `handle` -> `render` -> `shouldReport` -> `report`, described by the new `XErrorSource` and `XErrorContext`. Defaults: log only (no toast), `report` sends to Sentry when enabled and otherwise forwards to the replaced hooks, `buildErrorWidget` delegates to the previous builder; apps override any of them (e.g. report to a crash reporter directly). See `doc/ERROR_HANDLING.md`
    - Sentry is the default crash reporter, configured by classes with every value defaulted: `ErrorTrackingConstant` (`enabled`, `ERROR_TRACKING_DEBUG`) and `SentryConstant` (`dsn` written as a literal in the app's subclass, no define, `environment` from the flavor, `tracesSampleRate`, `configure`). Config is app-wide (the same for every flavor), so an app opts in with `BaseConstant.errorTracking => const YourSentryConstant()`, not on the per-flavor `EnvironmentConstant`; `runXApp` then starts `sentry_flutter` before the rest of boot (off in debug builds and without a valid DSN) and `XExceptionHandler.report` sends to it with a handled/unhandled mechanism per `XErrorSource`. Adds the `sentry_flutter` dependency, so every app now ships the native Sentry SDK. Errors before `runXApp` are not captured
- Deprecated
    - `runXApp(onFailed:)` is now optional and deprecated, as are `GeneralErrorHandle`, the global `onFailed`, `BaseXController.onFailed` / `onFailedDialog` and the constant's `onFailed` getter; use `XExceptionHandler` instead
- Breaking
    - `BaseConstant.deviceModel`, `osVersion`, `appVersion`, `deviceId` and `packageName` (all `RxString`) removed; read `baseConstant.deviceInfo.model` / `.osVersion` / `.id` and `baseConstant.appInfo.version` / `.packageName` instead. `appVersion` no longer defaults to `1.0.0`. `XController` removed (nothing instantiated it)
    - Constant classes renamed, no aliases kept: `BaseXConstant` and `DefaultBaseConstant` are merged into one concrete `BaseConstant` (every member defaulted), `XEnvironment` -> `EnvironmentConstant`, `XEnv` -> `EnvironmentResolver`, `XErrorTrackingConstant` -> `ErrorTrackingConstant`, `XSentryConstant` -> `SentryConstant`. The old `Environment` enum, `appEnv` and `runXApp(currentEnv:)` are kept (the env bar in `XBaseWidget` still reads `appEnv`)
    - Social login removed: the `SocialLogin` mixin (`loginFacebook` / `loginGoogle` / `loginApple`) and `SocialData` are gone, along with the `flutter_facebook_auth`, `sign_in_with_apple` and `google_sign_in` dependencies. Apps that need a provider add its plugin directly. This also drops the Facebook SDK's `FacebookClientToken` boot warning and the `sign_in_with_apple` Swift Package Manager warning
    - Map launcher removed: `openXMaps`, `openXPlatformMaps` and `openXGoogleMaps` (`x_widget/x_open_map.dart`) are gone, along with the `map_launcher` and `flutter_svg` dependencies. They were never exported from `base_x.dart`; apps that need either package add it directly
- Bug Fixes
    - The `App-Version`, `Device-Model`, `Device-ID` and `Os-Version` request headers were always empty (and `App-Version` a stale `1.0.0`) because nothing ever instantiated `XController`; `runXApp` now loads them

## [v1.1.0](https://github.com/YeeJiaWei/baseX/releases/tag/1.1.0) - 2026-10-30
- Breaking
    - `XLogger.httpBlock` is replaced by `XLogger.httpLine`: each HTTP exchange logs one row, `🟢`/`🔴` + method, full URL and status (e.g. `🟢 GET https://host/api/v1/banners/current → 200`). Request and response bodies are no longer logged; inspect them in DevTools' Network tab
    - An unrecognised `APP_ENV` (e.g. `prod`, `dev`) now throws a `FormatException` at boot instead of silently resolving to development; pass `development`, `staging` or `production`. Unset still defaults to development
- New
    - `runXApp(navigatorObservers:)` passes extra observers to the root `GetMaterialApp` (e.g. `FirebaseAnalyticsObserver` for screen views)
    - `runXApp(lockTextScale:, lockDisplaySize:)`, both default `true`: the app ignores the OS font size and display size (Android Display size, iOS Display Zoom). baseX is now a Flutter plugin (Android + iOS) to read the display zoom factor; see `doc/DISPLAY_LOCK.md`

## [v1.0.0](https://github.com/YeeJiaWei/baseX/releases/tag/1.0.0) - 2026-10-13
- Breaking
    - Minimum SDK raised to Dart `^3.13.0` / Flutter `>=3.47.0`
    - `Core` regrouped into feature folders (`app`, `auth`, `base`, `extension`, `logger`, `navigation`, `storage`)
- New
    - `XAuthStore` token store with drivers, install marker and lifecycle hooks (see `doc/AUTH.md`, `doc/FRESH_INSTALL.md`)
    - `PushNotifications` with FCM and Huawei Push Kit drivers, chosen per device by `resolvePushDriver`: permission asked once on demand, token lifecycle tied to `XAuthStore` sign-in/out, tap dedup (see `doc/notifications/push.md`)
    - `NotificationLinks` router for push and inbox taps: path patterns, handler classes, guards, event routes, cold-start hold (see `doc/notifications/notification_links.md`)
    - `PushPayload`: the fixed `payload` object (`type`, `link`, `delivery_id`, `params`) read from push data (see `doc/notifications/notification_payload.md`)
    - Getting-started guide for notifications (`doc/notifications/getting_started.md`)
    - Claude Code plugin ([baseX-claude-plugin](https://github.com/YeeJiaWei/baseX-claude-plugin)): `basex-api-service` and `basex-auth` skills plus a baseX detection hook
- Moved
    - Development continues at [YeeJiaWei/baseX](https://github.com/YeeJiaWei/baseX); `haolun1996/baseX` stays at `0.6.x`
- Bug Fixes
    - Error interceptor always completes the handler

<br />

***
<br />

Older releases (0.x, from haolun1996/baseX): [doc/changelog_0.x.md](doc/changelog_0.x.md)

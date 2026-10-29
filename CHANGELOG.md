# Change Log

## Unreleased
- Breaking
    - An unrecognised `APP_ENV` (e.g. `prod`, `dev`) now throws a `FormatException` at boot instead of silently resolving to development; pass `development`, `staging` or `production`. Unset still defaults to development
- New
    - `runXApp(navigatorObservers:)` passes extra observers to the root `GetMaterialApp` (e.g. `FirebaseAnalyticsObserver` for screen views)

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

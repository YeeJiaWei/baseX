# BaseX

Flutter app foundation: Dio API service, auth token store, push notifications,
notification links, navigation, storage, error handling and shared widgets.

This repository (`YeeJiaWei/baseX`) is where baseX is developed from `1.0.0`
on. The original `haolun1996/baseX` stays at `0.6.x` and receives no further
changes — point apps here.

## Install

baseX is not on pub.dev. Depend on it through git and pin a release tag:

```yaml
dependencies:
  baseX:
    git:
      url: https://github.com/YeeJiaWei/baseX.git
      ref: 1.0.0
```

Git dependencies take no version ranges, so every app pins an exact tag and
moves to a new one on purpose. Releases follow semantic versioning:

| Release | Tag | Means |
|---|---|---|
| Patch | `1.0.1` | fixes only |
| Minor | `1.1.0` | new features, existing code keeps compiling |
| Major | `2.0.0` | breaking changes — read the [changelog](CHANGELOG.md) before moving |

To work on baseX next to an app, override the dependency locally in a
gitignored `pubspec_overrides.yaml` in the app, so the committed pubspec keeps
pointing at the tag:

```yaml
dependency_overrides:
  baseX:
    path: ../baseX
```

`pubspec_overrides.yaml` replaces the pubspec's whole `dependency_overrides`
section rather than merging with it, so copy any overrides the app already has
into it.

## Docs

- [API Service](doc/API_SERVICE.md) — connections (`ApiXService` subclasses),
  registration via `ApiXServiceProvider`, service classes, multi-connection
  setups, and the `XUserSyncInterceptor` user-sync contract.
- [Auth](doc/AUTH.md) — the `XAuthStore` token store, its drivers and the
  sign-in / sign-out lifecycle.
- [Fresh install](doc/FRESH_INSTALL.md) — detecting a first launch and purging
  state left behind by a previous install.
- Notifications
  - [Getting started](doc/notifications/getting_started.md) — set up push and
    notification links in a new app, step by step.
  - [Push](doc/notifications/push.md) — `PushNotifications`, the FCM and
    Huawei drivers, permission and the token lifecycle.
  - [Notification links](doc/notifications/notification_links.md) — routing
    push and inbox taps: path patterns, handler classes, guards, event routes.
  - [Payload](doc/notifications/notification_payload.md) — the `payload`
    object the backend sends in a push.
- [Dependencies](doc/DEPENDENCIES.md) — update policy (security fixes only, no
  major bumps), how to audit against pub.dev advisories, and the audit log.
- [Changelog](CHANGELOG.md) — 1.0.0 and later; 0.x releases from the original
  package are in [doc/changelog_0.x.md](doc/changelog_0.x.md).

## Claude Code plugin

Skills for working with baseX in Claude Code (API service calls, auth store):

```
/plugin marketplace add YeeJiaWei/baseX-plugin
/plugin install basex@basex
```

# CLAUDE.md

baseX is the foundation package a new Flutter app starts from: install it, call
`runXApp`, and the app has its environment, API client, auth token store, push
notifications, navigation, storage, logging and error types wired up. Apps
depend on it by git tag (see `README.md`); it is not on pub.dev.

## Scope: core setup only

baseX holds what almost every app needs on day one and what the rest of baseX
builds on. Feature integrations an app opts into live in their own package or
in the app itself, never here.

**Belongs in baseX**
- App bootstrap: `runXApp`, `EnvironmentResolver`, service providers, display/text-scale lock
- API service (Dio connections, interceptors, envelope, error mapping)
- Auth token store (`XAuthStore`) and fresh-install handling
- Push notifications and notification links
- Navigation, storage, logger, base controller/widget, error types
- Crash reporting through Sentry (`BaseConstant.errorTracking`): the
  deliberate exception to the rule below (user decision 2026-11-03); the
  native Sentry SDK is the cost every app pays
- Small generic widgets with no extra native setup (`XCachedImage`, `XPicker`,
  `XSkeleton`, keyboard dismiss)
- Lint rules (`x_lint`)

**Goes in a separate package** (or the app)
- Sign-in providers (Google, Apple, Facebook, …)
- Map launchers, maps, location
- Payments / in-app purchase, ads, analytics
- Camera, media pickers, file sharing, anything else per-feature

Test before adding something: would an app that never uses it still have to
install the native SDK, run its pod/gradle setup, or add Info.plist /
AndroidManifest keys? If yes, it is a feature package, not baseX. Every native
plugin here is a cost every consuming app pays (build time, Swift Package
Manager warnings, SDK boot logs).

Social login (`SocialLogin`, `SocialData`) and the map launcher
(`openXMaps`) were removed after 1.1.0 under this rule; do not bring them back.

## Commands

```sh
flutter pub get
flutter analyze lib
flutter test
```

No fvm; `flutter` is on PATH. Tests live under `test/core/`.

## Layout

| Path | Holds |
|---|---|
| `lib/base_x.dart` | The public API: every `export … show …` here is a promise to apps |
| `lib/Core/app/` | `runXApp`, env, constants, service providers, display lock |
| `lib/Core/auth/` | `XAuthStore` and its drivers |
| `lib/Core/push/`, `lib/Core/notification_links/` | Push drivers (FCM, Huawei) and tap routing |
| `lib/Core/base/`, `navigation/`, `storage/`, `logger/`, `extension/` | Base classes and utilities |
| `lib/api_service/` | Connections, client, interceptors, support types |
| `lib/controller/`, `lib/helper/` | `XController`, `XLangController`, dark mode, scroll behaviour |
| `lib/model/`, `lib/custom_error/` | `XData` and UI models; typed errors |
| `lib/x_widget/` | Generic widgets |
| `lib/x_lint/` | Lint rules apps include |
| `ios/`, `android/` | The `BaseXPlugin` native side (display zoom channel) |
| `doc/` | Feature docs, indexed from `README.md` |

## Changes and releases

- **Public API is what `base_x.dart` exports.** Removing or changing an export
  is breaking; a file reachable only by deep import is internal.
- **Semver** per the table in `README.md`: breaking → major.
- **CHANGELOG first.** Add the entry under `## Unreleased` (Breaking / New /
  Bug Fixes) with the change; the release renames it to the version.
- **Docs travel with code.** A new feature gets a `doc/` page and a line in the
  README's Docs list; a removed one loses both, plus its row in
  `doc/DEPENDENCIES.md`.
- **Dependencies** follow `doc/DEPENDENCIES.md`: security bumps only, no major
  bumps outside a breaking release.
- **Releases:** semver tag on `main` (bare version, e.g. `1.1.0`); the GitHub
  release title is the bare version and its notes are that version's
  CHANGELOG section. Pushing `main` and tags is the maintainer's step.
- **Commits** use conventional style with a scope: `feat(app): …`,
  `feat(logger)!: …` for breaking, `docs: …`, `chore(release): x.y.z`.

## Working next to an app

Apps point at a local checkout through a gitignored `pubspec_overrides.yaml`
(`baseX: path: ../baseX`). After changing baseX, run `flutter pub get` and
`flutter analyze lib` in the consuming app too: a removed export shows up
there, not here.

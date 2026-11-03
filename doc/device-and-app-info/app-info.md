# App info

`AppInfo` is a process-wide singleton holding plain string facts about the installed app: name, version, build number and package name. `runXApp` loads it in `startApp` right after `baseConstant` is assigned; a failure is logged and never blocks boot, and the fields then keep their empty-string defaults.

## Reading it

```dart
final version = baseConstant.appInfo.version;
```

## `AppInfo`

| Property | Type | Source | Notes |
|----------|------|--------|-------|
| `name` | `String` | `package_info_plus` `appName` | App display name. Empty until load completes |
| `version` | `String` | `package_info_plus` `version` | Marketing version, e.g. `1.2.0`. Empty until load completes |
| `buildNumber` | `String` | `package_info_plus` `buildNumber` | Empty until load completes |
| `packageName` | `String` | `package_info_plus` `packageName` | Bundle id / application id. Empty until load completes |


## In tests

`load()` talks to platform plugins, which are not available in a unit or widget test. Set the
values directly with `debugSet` instead. `debugSet` is `@visibleForTesting`, and any
argument you leave out is reset to an empty string.

```dart
AppInfo.instance.debugSet(name: 'Demo', version: '1.0.0', buildNumber: '1', packageName: 'com.example.demo');
```

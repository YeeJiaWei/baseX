# Device info

`DeviceInfo` is a process-wide singleton holding plain string facts about the device: OS version, model and device id. `runXApp` loads it in `startApp` right after `baseConstant` is assigned; a failure is logged and never blocks boot, and the fields then keep their empty-string defaults.

## Reading it

```dart
final model = baseConstant.deviceInfo.model;
```

## `DeviceInfo`

| Property | Type | Source | Notes |
|----------|------|--------|-------|
| `os` | `String` | `GetPlatform.isIOS` | `'ios'` or `'android'`. Needs no load, always available |
| `osVersion` | `String` | Android: `device_info_plus` `androidInfo.version.release`. iOS: `iosInfo.systemVersion` | Empty until load completes |
| `model` | `String` | Android: `androidInfo.manufacturer` + `androidInfo.model`. iOS: `iosInfo.utsname.machine.iOSProductName` (`ios_utsname_ext`) | Empty until load completes. Android reads like `samsung SM-S918B`; iOS is the marketing name, e.g. `iPhone 15 Pro` |
| `id` | `String` | Android: `android_id` `AndroidId().getId()`. iOS: `iosInfo.identifierForVendor` | Empty until load completes. iOS: resets when all of the vendor's apps are uninstalled |

On platforms other than Android and iOS, `load()` leaves `osVersion`, `model` and `id` empty.

## In tests

`load()` talks to platform plugins, which are not available in a unit or widget test. Set the
values directly with `debugSet` instead. `debugSet` is `@visibleForTesting`, and any
argument you leave out is reset to an empty string.

```dart
DeviceInfo.instance.debugSet(osVersion: '17.5', model: 'iPhone 15', id: 'test-device');
```

`DeviceInfo.debugSet` has no `os` argument: `os` always comes from the platform.

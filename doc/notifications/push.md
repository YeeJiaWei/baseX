# Push — `PushNotifications`

Push plumbing every baseX app repeats — permission, token lifecycle, foreground /
background / tap listeners, cold-start handling, dedup — lives in baseX. The app
supplies only what is domain-specific through a `PushHandler`.

```
                    +--------------------------------------------+
 runXApp / provider | baseX  ·  lib/Core/push/                   |
 -----------------> |  PushNotifications (GetxService)           |
                    |   - permission + iOS foreground options    |
                    |   - onMessage / onMessageOpenedApp / bg    |
                    |   - APNS wait -> getToken                  |
                    |   - token refresh: register new,           |
                    |     unregister previous                    |
                    |   - permission: live, prompt once          |
                    |   - cold-start tap -> onOpened (app holds) |
                    |   - dedup by message key, lastMessageType  |
                    |  PushDriver <-- FcmPushDriver / HmsPush- |
                    |                   Driver (per device)      |
                    +--------+---------------------^-------------+
                             | calls hooks         | XAuthStore lifecycle:
                             v                     | onSignedIn  -> registerToken
                    +--------------------------+   | onSignedOut -> unregisterToken
                    | App: PushHandler         |---+
                    |  registerToken / unregisterToken -> backend
                    |  onForeground -> in-app banner, refresh lists
                    |  onOpened     -> NotificationLinks.handleEvent
                    |  onReceipt    -> delivery tracking
                    +--------------------------+
```

The message shape the backend sends is in
[notification_payload.md](notification_payload.md).

## Contract

```dart
abstract class PushHandler {
  /// Sends the token, its provider and the live OS permission to the backend.
  Future<void> registerToken(PushRegistration registration);
  Future<void> unregisterToken(String token);
  void onForeground(PushMessage message) {}
  /// Tap on a push — app running, in background, or cold start.
  /// Default: NotificationLinks.instance.handleEvent(...) when bound.
  void onOpened(PushMessage message) {}
  void onReceipt(PushMessage message, PushReceipt receipt) {}  // RECEIVED / OPENED
  String? messageKey(PushMessage message) => message.id;
}

class PushRegistration {
  final String token;
  final PushPlatform platform;   // ios, android
  final PushProvider provider;   // fcm, hms
  final PushPermission permission;
}

enum PushProvider { fcm, hms }

abstract class PushDriver {
  PushProvider get provider;
  Future<PushPermission> getPermission();      // read only, never prompts
  Future<PushPermission> requestPermission();  // shows the OS prompt
  Future<void> setForegroundPresentation();    // iOS banner while in foreground
  Future<String?> getToken();                  // iOS: waits for APNS first
  Future<void> deleteToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onForeground;
  Stream<PushMessage> get onOpened;
  Future<PushMessage?> getInitialMessage();
}

enum PushPermission { notDetermined, denied, authorized, provisional }

class PushNotifications extends GetxService {
  static Future<PushNotifications> bind({
    required PushDriver driver,
    required PushHandler handler,
  });
  static PushNotifications get instance;
  static PushNotifications? get maybeInstance;

  String? get token;
  Rx<PushPermission> get permission;   // live; re-read on every app resume
  bool get isAuthorized;               // authorized or provisional
  Rxn<String> get lastMessageType;     // reset to null then set, so ever() fires on repeats

  /// Shows the OS prompt once per install (flag in shared prefs), then
  /// re-registers. Later calls only re-read the permission.
  Future<PushPermission> promptIfNeeded();

  /// Re-sends the current token with the live permission.
  Future<void> refreshRegistration();

  /// Removes the current token from the backend, giving up after 5 seconds so
  /// a stalled request cannot hold sign-out. XAuthStore.signOut() calls this
  /// first, while the bearer token is still valid.
  Future<void> unregisterCurrentToken();
}
```

`PushMessage` wraps the platform message (`id`, `type`, `title`, `body`,
`data`), so apps never import `firebase_messaging` directly.

## Providers

One build ships both SDKs; the driver is chosen at runtime per device.

| Device | Driver | Token |
|---|---|---|
| iOS | `FcmPushDriver` | FCM (via APNS) |
| Android with Google services (including older Huawei phones that still have GMS) | `FcmPushDriver` | FCM |
| Android with HMS Core and no Google services (newer Huawei phones) | `HmsPushDriver` | Huawei Push Kit |
| Android with neither | none | no push |

`resolvePushDriver` makes the call:

```dart
final driver = await resolvePushDriver(
  fcm: () => FcmPushDriver(backgroundHandler: pushBackgroundHandler),
  hms: () => HmsPushDriver(backgroundHandler: hmsBackgroundHandler),
);
if (driver != null) {
  await PushNotifications.bind(driver: driver, handler: AppPushHandler());
}
```

It returns `null` when the device has no push service, so the app skips
`bind`. iOS and GMS devices always get FCM. The checks are `baseConstant.isGMS()`
and `baseConstant.isHMS()` (HMS is only chosen when HMS Core is present and GMS
is not), and can be injected through `isGms` / `isHms` / `isIOS` for tests. If
detection throws, it logs and falls back to FCM.

Each `PushRegistration` carries the `provider`, so the backend knows which
service to send a token through. When a device switches provider between
launches (for example Google services were removed), the new token differs from
the persisted one, so the normal token-change path runs: `registerToken(new)`,
then `unregisterToken(previous)`.

## Permission

`bind()` never prompts. iOS allows one system prompt per install, and boot runs
before the user knows what the app is. The app calls `promptIfNeeded()` from a
screen where the ask has a visible reason.

- **"Already asked" is a shared-prefs flag**, not `notDetermined` — Android
  never reports `notDetermined`, so "denied" and "never asked" look the same
  there. An install that is already authorized sets the flag without prompting.
  The flag is only set after the prompt resolves, so a failed call doesn't burn
  the one prompt.
- **Permission is live, never persisted.** It is read at bind and on every app
  resume (the user fixes it in Settings, then comes back). When it changed,
  `refreshRegistration()` runs so the backend knows.

### HMS permission

Push Kit has no FCM-style permission prompt. `HmsPushDriver` uses the Android
implementation of `flutter_local_notifications`:

- `getPermission()` maps `areNotificationsEnabled()` to `authorized` / `denied`
  (it never reports `notDetermined`, same as FCM on Android).
- `requestPermission()` calls `requestNotificationsPermission()` (Android 13+
  shows the system prompt; older versions have nothing to ask) and then reports
  the enabled state.
- `setForegroundPresentation()` does nothing.

## Bind during boot

```dart
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  // runs in a separate isolate — keep it minimal
}

await PushNotifications.bind(
  driver: FcmPushDriver(backgroundHandler: pushBackgroundHandler),
  handler: AppPushHandler(),
);
```

The background handler must be a top-level function in the app — Firebase
spawns a fresh isolate for it, which cannot see anything registered at runtime.
It belongs to the FCM driver because its signature is Firebase's.

`HmsPushDriver` takes its own optional `backgroundHandler`, a top-level
`@pragma('vm:entry-point')` function that receives a `huawei_push`
`RemoteMessage`; it is registered with the plugin on construction.

## Lifecycle

| Event | PushNotifications does | Handler hook |
|---|---|---|
| `bind()` | read permission, iOS foreground presentation, wire listeners; the token fetch runs in the background so boot never waits on it (iOS can wait ~10s for the APNS token) | — |
| token ready | persist token | `registerToken` |
| token refresh | persist new token | `registerToken(new)`, then `unregisterToken(previous)` |
| app resume | re-read permission; if changed, `refreshRegistration()` | `registerToken` |
| `promptIfNeeded()` | prompt once, then `refreshRegistration()` | `registerToken` |
| `XAuthStore.onSignedIn` | `refreshRegistration()` | `registerToken` |
| `XAuthStore.onSignedOut` | — | `unregisterToken` |
| foreground message | publish `lastMessageType` | `onReceipt(RECEIVED)`, `onForeground` |
| tap (running or background) | dedup, publish type | `onReceipt(OPENED)`, `onOpened` |
| tap (cold start) | dedup, publish type | `onReceipt(OPENED)`, `onOpened` |

Token fetch is best-effort: iOS simulators never get an APNS token, so the
listeners are wired before the token is requested and push delivery still works.

A cold-start tap goes to `onOpened` like any other tap. It must not navigate
before the splash screen has built the stack, so the app calls
`NotificationLinks.instance.hold()` at boot and the link waits there until
splash calls `release()` or `discard()` — `PushNotifications` keeps no stash of
its own.

## Dedup

A cold-start tap can arrive through both `getInitialMessage` and
`onMessageOpenedApp`. `PushNotifications` keeps the keys it has handled and drops repeats.
The key is `handler.messageKey(message)` — override it when the backend sends
its own delivery id.

## Android foreground

Android shows no system banner while the app is in the foreground; iOS does
(enabled at bind). Showing something in-app on Android is the handler's job in
`onForeground`.

## Dependencies

`FcmPushDriver` needs `firebase_core` and `firebase_messaging`. Firebase config
files (`google-services.json`, `GoogleService-Info.plist`) and
`Firebase.initializeApp` stay in the app.

`HmsPushDriver` needs `huawei_push` (a baseX dependency) and the Android setup
below. Both SDKs compile into the same build; a device only talks to the one
`resolvePushDriver` picks.

## HMS driver details

`HmsPushDriver` talks to the plugin through the `HmsPushClient` interface
(`DefaultHmsPushClient` in production, a fake in tests).

- **Token.** `huawei_push` delivers the token on a stream after `Push.getToken('')`,
  so `getToken()` requests it and waits up to 10 seconds for the first non-empty
  token. On timeout or error it logs and returns `null`; a late token still
  arrives through `onTokenRefresh`. Tokens that `getToken()` already returned are
  not repeated as refreshes.
- **Message data.** The `data` of a Huawei message is one JSON string. The driver
  decodes it into `PushMessage.data`; invalid or non-object JSON becomes an
  empty map and a log line. `PushMessage.type` is `data['type']`.
- **Taps.** `onOpened` and `getInitialMessage` read the notification-opened
  event, which carries the intent extras plus `remoteMessage`. Extras and the
  decoded `data` are merged, with the decoded `data` winning.
- **Foreground.** `onForeground` is the plugin's data-message stream.

## Android setup for HMS

1. **AppGallery Connect project.** In AppGallery Connect create a project and an
   Android app with the app's package name, then enable **Push Kit** for it
   (Project settings, Manage APIs).
2. **Signing fingerprint.** Add the SHA-256 certificate fingerprint of every
   signing key you ship with (debug, release, store) under the app's *SHA-256
   certificate fingerprint* in AppGallery Connect. Without it the token request
   fails.
3. **Config file.** Download `agconnect-services.json` and put it in
   `android/app/`.
4. **Huawei Maven repository and the AGConnect plugin** in `android/build.gradle`:

   ```groovy
   buildscript {
       repositories {
           google()
           mavenCentral()
           maven { url 'https://developer.huawei.com/repo/' }
       }
       dependencies {
           classpath 'com.huawei.agconnect:agcp:1.9.1.304'
       }
   }

   allprojects {
       repositories {
           google()
           mavenCentral()
           maven { url 'https://developer.huawei.com/repo/' }
       }
   }
   ```

   Apps on the declarative `plugins {}` setup add the same `maven { url ... }`
   to `pluginManagement.repositories` and `dependencyResolutionManagement.repositories`
   in `settings.gradle`.

5. **Apply the plugin** in `android/app/build.gradle`:

   ```groovy
   plugins {
       id "com.android.application"
       id "com.huawei.agconnect"
       id "kotlin-android"
       id "dev.flutter.flutter-gradle-plugin"
   }
   ```

   The versions above are the ones shipped with `huawei_push` 6.15.0+300; use the
   current ones from the plugin's documentation if it has moved on.
6. **Release builds.** Keep the Huawei classes when shrinking, in
   `proguard-rules.pro` (rules from the plugin's example app):

   ```
   -keep class com.huawei.hianalytics.**{*;}
   -keep class com.huawei.updatesdk.**{*;}
   -keep class com.huawei.hms.**{*;}
   -keep class com.huawei.hms.flutter.**{*;}
   ```
7. **Token scope.** The default client requests tokens with an empty scope, which
   uses the app's own AppGallery Connect project.

# Push — `PushNotifications`

> **Status: proposed.** Nothing below is implemented yet. This is the design to
> review before the build starts.

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
                    |  PushDriver <-- FcmPushDriver (HMS later)  |
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
  /// Sends the token and the live OS permission to the backend.
  Future<void> registerToken(String token, PushPlatform platform, PushPermission permission);
  Future<void> unregisterToken(String token);
  void onForeground(PushMessage message) {}
  /// Tap on a push — app running, in background, or cold start.
  /// Default: NotificationLinks.instance.handleEvent(...) when bound.
  void onOpened(PushMessage message) {}
  void onReceipt(PushMessage message, PushReceipt receipt) {}  // RECEIVED / OPENED
  String? messageKey(PushMessage message) => message.id;
}

abstract class PushDriver {
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

  /// Removes the current token from the backend. XAuthStore.signOut() calls
  /// this first, while the bearer token is still valid.
  Future<void> unregisterCurrentToken();
}
```

`PushMessage` wraps the platform message (`id`, `type`, `title`, `body`,
`data`), so apps never import `firebase_messaging` directly.

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

## Lifecycle

| Event | PushNotifications does | Handler hook |
|---|---|---|
| `bind()` | read permission, iOS foreground presentation, wire listeners, then fetch the token | — |
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

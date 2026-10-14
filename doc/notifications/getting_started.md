# Getting Started — push notifications and notification links

baseX gives a new app the whole push stack: permission, token lifecycle (FCM, or
Huawei Push Kit on phones without Google services), foreground / background /
tap handling, and a path router for the links a notification carries. The app
writes four small pieces: a `PushHandler`, a route table, the boot wiring and
a splash exit. This guide builds them in order for a generic shop app
(`orders/42`).

```
  push tap / inbox row tap
          |
          v
  +------------------------------------------------------------+
  | NotificationLinks                                          |
  |   event routes (payload type) -> path routes (orders/42)   |
  +------------------------------------------------------------+
          |
          v
  your LinkHandler / LinkRoute -> opens the page

  device token
          |
          v
  +------------------------------------------------------------+
  | PushNotifications  <-- FcmPushDriver | HmsPushDriver       |
  +------------------------------------------------------------+
          |
          v
  your PushHandler.registerToken -> app backend
```

Reference: [push.md](push.md) · [notification_links.md](notification_links.md) ·
[notification_payload.md](notification_payload.md)

## 1. Install

Add baseX to `pubspec.yaml` (use your usual baseX dependency source):

```yaml
dependencies:
  baseX:
    git:
      url: <your baseX repository>
  firebase_core: ^4.0.0
  firebase_messaging: '>=16.0.0 <16.4.0'
  huawei_push: ^6.15.0+300   # only needed to import its RemoteMessage in step 5
```

Keep the `firebase_messaging` range in step with baseX's own `pubspec.yaml`.

Firebase setup stays in the app:

1. Add the Firebase app for Android and iOS, then put `google-services.json` in
   `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`.
2. On iOS enable the *Push Notifications* and *Background Modes > Remote
   notifications* capabilities and upload the APNs key in the Firebase console.
3. Call `Firebase.initializeApp()` in `main()` after
   `WidgetsFlutterBinding.ensureInitialized()` and before anything that binds
   push (step 5).

### Huawei phones without Google services (optional)

Skip this if you do not ship to newer Huawei devices. One build carries both SDKs;
a Huawei phone with Google services still uses FCM. For the rest you need:

- An AppGallery Connect project with an Android app (your package name) and
  **Push Kit** enabled.
- The **SHA-256 fingerprint** of every signing key you ship (debug, release,
  store) added in AppGallery Connect.
- `agconnect-services.json` in `android/app/`.
- The Huawei Maven repository and the `com.huawei.agconnect` Gradle plugin.
- The `BackgroundMessageBroadcastReceiver` entry in `AndroidManifest.xml`, or
  background data messages never reach Dart.
- ProGuard keep rules for release builds.

Copy-paste snippets for each item are in
[push.md, Android setup for HMS](push.md#android-setup-for-hms).

## 2. Write a `PushHandler`

The handler holds everything domain-specific. Only `registerToken` and
`unregisterToken` are required.

```dart
// lib/app/core/push/app_push_handler.dart
class AppPushHandler extends PushHandler {
  @override
  Future<void> registerToken(PushRegistration registration) async {
    await Get.find<DeviceService>().register(
      token: registration.token,
      platform: registration.platform.name,   // ios | android
      provider: registration.provider.name,   // fcm | hms
      notificationsAllowed: registration.permission == PushPermission.authorized ||
          registration.permission == PushPermission.provisional,
    );
  }

  @override
  Future<void> unregisterToken(String token, PushProvider provider) =>
      Get.find<DeviceService>().unregister(token: token, provider: provider.name);

  @override
  void onForeground(PushMessage message) {
    // Android shows no banner in the foreground; show one in-app and refresh lists.
    AppSnackbar.info(message.title ?? 'New notification');
  }

  @override
  void onReceipt(PushMessage message, PushReceipt receipt) {
    // receipt is received (foreground arrival) or opened (tap); report to the backend.
  }

  @override
  }
```

- `registerToken` runs when a token is first obtained, when it rotates, when the
  OS permission changes and after sign-in. Make the backend call idempotent.
- `unregisterToken` receives the provider the token was issued by, so the backend
  removes it from the right service.
- `messageKey` is not overridden: it defaults to the payload's `delivery_id`, else
  `message.id`. baseX drops a tap whose key it has already handled (a cold-start
  tap can arrive twice).
- `onOpened` is **not** overridden: by default a tap goes to
  `NotificationLinks.maybeInstance?.handleEvent(payload.type, params: payload.params, link: payload.link)`.
  Override it only to do extra work, and call `super.onOpened(message)` to keep
  the routing.

## 3. Write the route table

```dart
// lib/app/core/notification_links/app_notification_links.dart
class AppNotificationLinks extends NotificationLinkConfig {
  // Links are plain paths such as `orders/42`. Override `scheme` only if the
  // backend also writes `shop://orders/42`.

  @override
  List<LinkHandler> get routes => [
        LinkRoute('orders', (_) => Get.toNamed(AppRoutes.orders)),
        LinkRoute('help/**', (_) => Get.toNamed(AppRoutes.help)),
        OpenOrderLink(),
      ];

  @override
  List<EventHandler> get events => [
        OrderEvent(),
        EventRoute(
          types: {'PLAN_EXPIRED'},
          action: (_) => Get.toNamed(AppRoutes.upgrade),
        ),
      ];
}
```

One handler class for logic that is more than a page push:

```dart
// lib/app/core/notification_links/links/open_order_link.dart
class OpenOrderLink extends LinkHandler {
  @override
  String get pattern => 'orders/{id:int}';

  @override
  Future<void> handle(LinkMatch link) =>
      Get.toNamed(AppRoutes.orderDetail, arguments: {'id': link.int('id')});
}
```

One event handler for a push `type` (it runs before the link fallback):

```dart
// lib/app/core/notification_links/events/order_event.dart
class OrderEvent extends EventHandler {
  @override
  Set<String> get types => {'ORDER_SHIPPED', 'ORDER_DELIVERED'};

  @override
  Map<String, LinkParam> get require => {'order_id': LinkParam.int};

  @override
  Future<void> handle(LinkMatch event) =>
      Get.toNamed(AppRoutes.orderDetail, arguments: {'id': event.int('order_id')});
}
```

Route order does not matter: the most specific pattern wins, and two routes that
tie throw at `bind()`. Patterns, precedence, guards (for example a signed-in
check), `canHandle` and error hooks are in
[notification_links.md](notification_links.md).

## 4. Bind at startup

Order matters. `NotificationLinks` is bound and held **synchronously**, before
anything can deliver a tap; push is then set up without being awaited so the
first frame is not blocked (the iOS token fetch alone can take seconds).

```dart
// lib/main.dart
import 'package:firebase_messaging/firebase_messaging.dart' as fcm;
import 'package:huawei_push/huawei_push.dart' as hms;

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(fcm.RemoteMessage message) async {
  // Separate isolate: no GetX, no app state. Keep it minimal.
}

@pragma('vm:entry-point')
void hmsBackgroundHandler(hms.RemoteMessage message) {
  // Separate isolate, same rules.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 1. Router first, and hold taps until the splash has built the stack.
  NotificationLinks.bind(AppNotificationLinks());
  NotificationLinks.instance.hold();

  runApp(const ShopApp());

  // 2. Push after the first frame is scheduled; not awaited.
  unawaited(_setUpPush());
}

Future<void> _setUpPush() async {
  final driver = await resolvePushDriver(
    fcm: () => FcmPushDriver(backgroundHandler: pushBackgroundHandler),
    hms: () => HmsPushDriver(backgroundHandler: hmsBackgroundHandler),
  );
  if (driver == null) return;   // Android with neither Google services nor HMS Core

  await PushNotifications.bind(driver: driver, handler: AppPushHandler());
  await PushNotifications.instance.promptIfNeeded();
}
```

- Both `RemoteMessage` types share a name, hence the `as fcm` / `as hms` aliases.
  The FCM handler returns a `Future<void>`; the HMS one is a plain `void`
  function. Both must be top-level (or static) with `@pragma('vm:entry-point')`.
- Wire anything else your handler needs (`DeviceService`, `Get.put`) **before**
  `_setUpPush()`; `registerToken` can fire as soon as `bind` returns.
- `bind()` never shows the OS permission prompt. `promptIfNeeded()` asks once per
  install, then re-registers. Calling it at boot is the simplest option; to ask
  with a visible reason instead (iOS gives one prompt per install), call it later
  from a screen and drop it from `_setUpPush()`:

  ```dart
  await PushNotifications.instance.promptIfNeeded();
  ```

## 5. Release the hold from the splash

While held, a tapped link is queued instead of run, so a cold-start tap cannot
navigate before the splash has built the stack. Every splash exit must end the
hold:

```dart
// splash controller
Future<void> _routeFromSplash() async {
  final destination = await _pickDestination();

  if (destination == AppRoutes.home) {
    await Get.offAllNamed(AppRoutes.home);
    await NotificationLinks.instance.release();   // runs the queued link on top of home
  } else {
    NotificationLinks.instance.discard();         // login, onboarding, update-required...
    await Get.offAllNamed(destination);
  }
}
```

Miss one exit (an error path, a forced-update screen) and `hold` stays on: every
later tap is queued and never runs. If a link should survive a login, a guard can
keep it with `holdLink` (see notification_links.md, Guards).

## 6. Inbox rows

Taps inside the app need no hold. Route the row's link:

```dart
onTap: () => NotificationLinks.instance.handle(notification.link),
```

`handle` takes the link string and defaults to `LinkSource.inbox`; it returns
`true` when a route ran. To make an inbox row behave exactly like the push,
including event routes, call
`NotificationLinks.instance.handleEvent(row.type, params: row.params, link: row.link)`.

## 7. Sign-in and sign-out

Nothing to wire if the app uses baseX's `XAuthStore`:

- `signIn(token)` stores the token, runs `onSignedIn`, then calls
  `PushNotifications.refreshRegistration()` so your `registerToken` sends the
  device token now that the backend can attribute it to a user.
- `signOut()` calls `PushNotifications.unregisterCurrentToken()` first, while the
  bearer token is still valid (it gives up after 5 seconds so a stalled request
  cannot hold sign-out), then runs the `remote` revoke callback, clears the token
  and runs `onSignedOut`.

Both are no-ops when push is not bound (for example a phone with no push service).

## 8. Backend checklist

- Store the **provider** (`fcm` / `hms`) next to each token and send each token
  through its own service: FCM HTTP v1 for `fcm`, Huawei Push Kit for `hms`.
- Every message carries `data.payload`, a JSON string holding `type`
  (`UPPER_SNAKE`), an optional plain-path `link` (`orders/1042`), an optional
  `delivery_id` and optional `params` with real JSON types.
- Send a `notification` block (title, body) for anything the user should see.
- Always send `link`, even when an event route handles the type, and never change
  a link path in place: installed old versions still receive pushes.
- Remove a token when `unregisterToken` arrives, and when the provider reports
  it as invalid.

Full field tables, platform options and the Huawei envelope are in
[notification_payload.md](notification_payload.md).

## 9. Test it

- [ ] **Cold start:** kill the app, tap a push. Splash shows, then the link opens
  on top of home.
- [ ] **Foreground, iOS:** the system banner appears; `onForeground` runs.
- [ ] **Foreground, Android:** no system banner; your in-app notice appears.
- [ ] **Background:** tap a push with the app backgrounded; the link opens.
- [ ] **Token refresh:** the backend receives the new token, then the old one is
  unregistered (reinstall or clear app data to force one).
- [ ] **Logout:** the token is removed from the backend before the session ends,
  and no push arrives afterwards.
- [ ] **Huawei phone without GMS:** the backend receives a token with provider
  `hms`; a background tap and a cold-start tap both open the link.
- [ ] **Phone with neither service:** the app boots normally, `resolvePushDriver`
  returns `null` and nothing crashes.
- [ ] **Permission:** deny the prompt, enable notifications in system Settings,
  return to the app; the backend gets a registration with the new permission.

## 10. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No token on the iOS simulator | Simulators have no APNS token, so the FCM token is skipped (logged as a warning). Push listeners still work; test tokens on a real device. |
| Taps never open anything | The hold was never ended. Check that the splash calls `release()` or `discard()` on every exit, and that `NotificationLinks.bind` ran before the tap. A link with a scheme your config does not declare, or that matches no route, only logs through `onUnknown`. |
| Huawei token never arrives | Check, in order: Push Kit enabled in AppGallery Connect, the SHA-256 fingerprint of the key you signed with (debug and release differ), `agconnect-services.json` from the same project in `android/app/`, the `com.huawei.agconnect` plugin applied. `getToken()` waits 10 seconds, then returns `null`. |
| Huawei background messages missing | The `BackgroundMessageBroadcastReceiver` entry is missing from the app's `AndroidManifest.xml`, or the background handler is not top-level with `@pragma('vm:entry-point')`. |
| Permission prompt never shows again | By design: `promptIfNeeded()` prompts once per install and stores a `push_prompt_shown` flag in shared preferences. After that the user must enable notifications in system Settings. Clear app data (or reinstall) to test the prompt again. |
| A tap runs twice or not at all | `messageKey` is deduplicating on a key the backend repeats. Return a delivery id that is unique per send, or `null` to disable dedup. |

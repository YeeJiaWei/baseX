# Notification Links — `NotificationLinks`

New app? Start with the [getting-started guide](getting_started.md).

One router for the links that notifications carry: push taps and in-app inbox
rows. The app declares routes as path patterns instead of hand-parsing
`uri.pathSegments`, and puts any non-trivial logic in handler classes.

**Scope: notifications only.** These links are written by the app's own
backend and reach the app only through a notification. They are not public
deep links — nothing here registers a URL scheme or universal link with the
OS, so a link shared outside the app opens nothing. Public deep links are a
separate feature with their own allow-list and abuse checks.

```
  push tap (PushNotifications) ---+
                                  +--> NotificationLinks.handle(link | event)
  inbox row tap ------------------+          |
                                             v
                           1. event routes: match on push `type` (+ data)
                                             | no match -> use data[linkKey]
                                             v
                           2. scheme check (the app's own scheme only)
                                             |
                                             v
                           3. path routes, most specific first:
                              literal > {id:int} > {id} > * > **
                                             | no match
                                             v
                           4. fallback: log + onUnknown hook
```

The fields the backend must send are in
[notification_payload.md](notification_payload.md).

The examples below use a generic shop app — orders, chat, settings — with
links such as `shop://orders/42` and push types such as `ORDER_SHIPPED`.

## Contract

```dart
abstract class NotificationLinkConfig {
  /// The scheme the backend writes links with, e.g. 'shop'.
  String get scheme;

  /// Payload key holding the link inside a push's data.
  String get linkKey => 'link';

  /// Path routes — closures (`LinkRoute`) and handler classes mixed freely.
  /// Order does not matter — precedence decides (see below).
  List<LinkHandler> get routes;

  /// Push-payload routes, tried before falling back to `data[linkKey]`.
  List<EventHandler> get events => const [];

  /// Guards run before every route's own guards; a route opts out with
  /// `bool get public => true`.
  List<LinkGuard> get guards => const [];

  /// Called when nothing matched. Defaults to a log line.
  void onUnknown(Uri uri) {}

  /// Called when a handler or guard throws. Defaults to a log line; the
  /// router never rethrows, so a broken link can't crash a push tap.
  void onError(Uri uri, Object error, StackTrace stackTrace) {}
}

class NotificationLinks {
  static void bind(NotificationLinkConfig config);
  static NotificationLinks get instance;

  Future<bool> handle(String? link, {LinkSource source = LinkSource.inbox});  // true when a route ran
  Future<bool> handleEvent(String type, Map<String, dynamic> data);

  // Cold-start hold (see below)
  void hold();
  void holdLink(LinkMatch link);   // queue one link, keeping its source and data, without a global hold (used by guards)
  Future<void> release();
  void discard();
}
```

## Path patterns

| Pattern | Matches |
|---|---|
| `orders/history` | Exact text only |
| `{reference}` | One segment, passed as a string |
| `{id:int}` | One segment that must parse as an int. A non-number (`orders/abc`) falls through to the next route, so actions never call `int.tryParse` |
| `{kind:invoices\|receipts}` | One segment from a fixed list — covers renamed paths and aliases |
| `{section?}` | Optional last segment — `settings` and `settings/privacy` share one route |
| `*` | Any single segment |
| `**` | Zero or more trailing segments — `help/**` matches `help`, `help/faq`, `help/faq/123` |

Matching is case-sensitive, ignores a trailing slash, and ignores the query
string. Query parameters are still readable from the match.

### Precedence

The most specific route wins, whatever order the routes are listed in. Routes
are compared segment by segment, left to right; at the first segment where they
differ, the higher rank wins:

1. literal (`history`)
2. constrained param (`{id:int}`, `{kind:invoices|receipts}`)
3. plain param (`{reference}`)
4. optional param (`{section?}`)
5. `*`
6. `**`

So `orders/history` beats `orders/{id:int}`, and `settings/notifications`
beats `settings/{section?}`. Two routes with the same rank on every segment
are a configuration error, thrown at `bind()` (not at link time).

### Link format

The host is the first path segment: `shop://orders/42` resolves to the path
`orders/42`. A link with any other scheme goes to `onUnknown` — the router
never opens `https://` or another app's scheme.

## Routes — closure or handler class

Every route is a `LinkHandler`. Write it one of two ways and mix both in the
same `routes` list:

| Use | When |
|---|---|
| `LinkRoute(pattern, action)` closure | the action is a page push or a few lines of logic |
| a class extending `LinkHandler` | the logic branches, awaits a service, needs guards, is reused, or deserves its own test |

### The base class

```dart
abstract class LinkHandler {
  /// Path pattern, e.g. 'orders/{id:int}'.
  String get pattern;

  /// Checks run before [handle], in order (see Guards).
  List<LinkGuard> get guards => const [];

  /// Skips the app-wide guards on the config.
  bool get public => false;

  /// Last-moment veto: return false and the router tries the next
  /// matching route, as if this one never matched.
  Future<bool> canHandle(LinkMatch link) async => true;

  /// Does the work — navigate, call services, show a dialog.
  Future<void> handle(LinkMatch link);
}

/// The closure shortcut is just a handler whose [handle] calls [action].
class LinkRoute extends LinkHandler {
  LinkRoute(this.pattern, this.action, {this.guards = const [], this.public = false});

  @override
  final String pattern;
  @override
  final List<LinkGuard> guards;
  @override
  final bool public;
  final Future<void> Function(LinkMatch link) action;

  @override
  Future<void> handle(LinkMatch link) => action(link);
}
```

The action receives a `LinkMatch`, named `link` in these examples (`_` when
the action doesn't read it). It gives:

| Accessor | Returns |
|---|---|
| `link.param('name')` | `String?` — path param |
| `link.int('name')` | `int` — only valid on a `{name:int}` param |
| `link.rest` | `List<String>` — segments captured by `**` |
| `link.query` | `Map<String, String>` — query string |
| `link.uri` | the original `Uri` |
| `link.data` | push payload when the link came from an event, else empty |
| `link.source` | `LinkSource.push` or `.inbox` |

### 1. Closure — page push

```dart
LinkRoute('help/**', (_) => Get.toNamed(AppRoutes.help)),
```

### 2. Closure — short logic

A few lines of branching still fit inline:

```dart
LinkRoute('settings/{section?}', (link) async {
  final tabIndex = switch (link.param('section')) {
    'notifications' => 1,
    'privacy' => 2,
    _ => 0,
  };
  await Get.toNamed(AppRoutes.settings, arguments: {'tab': tabIndex});
}),
```

### 3. Handler class — app-state-aware navigation

Opening an order depends on where the user is. If the home shell with the
bottom bar is already built, pop back to it and switch to the Orders tab so the
bar stays; if not (a push opening the app cold), push the standalone page.
That is too much for a closure, and the event handler below reuses it.

```dart
// lib/app/core/notification_links/links/open_order_link.dart
class OpenOrderLink extends LinkHandler {
  @override
  String get pattern => 'orders/{id:int}';

  @override
  Future<void> handle(LinkMatch link) => openOrder(link.int('id'));

  /// Shows [orderId] inside the home shell when it exists, else as its own page.
  static Future<void> openOrder(int orderId) async {
    if (Get.isRegistered<HomeShellController>()) {
      Get.until((route) => route.settings.name == AppRoutes.home || route.isFirst);
      Get.find<HomeShellController>().openOrdersTab(focusOrderId: orderId);
      return;
    }

    await Get.toNamed(AppRoutes.orderDetail, arguments: {'id': orderId});
  }
}
```

### 4. Handler class — calls a service and branches on the result

A "complete your payment" push may arrive after the user already paid on
another device. Look the payment up first and land on the right page.

```dart
// lib/app/core/notification_links/links/payment_link.dart
class PaymentLink extends LinkHandler {
  @override
  String get pattern => 'payments/{reference}';

  @override
  Future<void> handle(LinkMatch link) async {
    final reference = link.param('reference')!;
    final payment = await Get.find<PaymentService>().find(reference);

    if (payment == null) {
      AppSnackbar.error('This payment is no longer available.');
      return;
    }

    if (payment.isPaid) {
      await Get.toNamed(AppRoutes.receipt, arguments: {'reference': reference});
      return;
    }

    await Get.toNamed(AppRoutes.checkout, arguments: {'reference': reference});
  }
}
```

### 5. Handler class — `canHandle` to defer to another route

`canHandle` returning false makes the router try the next matching route.
Here a chat link for a conversation the user has since left falls through to
the `chat/**` route, which opens the conversation list.

```dart
// lib/app/core/notification_links/links/open_conversation_link.dart
class OpenConversationLink extends LinkHandler {
  @override
  String get pattern => 'chat/{conversationId}';

  @override
  Future<bool> canHandle(LinkMatch link) async =>
      Get.find<ChatService>().isMember(link.param('conversationId')!);

  @override
  Future<void> handle(LinkMatch link) => Get.toNamed(
        AppRoutes.conversation,
        arguments: {'id': link.param('conversationId')},
      );
}

LinkRoute('chat/**', (_) => Get.toNamed(AppRoutes.conversations)),
```

## Guards

A guard is a reusable check that runs before `handle`, like route middleware.
Guards run in the order listed; the first one that doesn't allow decides.

```dart
abstract class LinkGuard {
  Future<GuardResult> check(LinkMatch link);
}

// GuardResult.allow()   → next guard, then handle()
// GuardResult.skip()    → try the next matching route
// GuardResult.stop()    → the guard dealt with it (redirected, showed a prompt); nothing else runs
```

### Signed-in guard — holds the link through login

```dart
// lib/app/core/notification_links/guards/signed_in_guard.dart
class SignedInGuard extends LinkGuard {
  @override
  Future<GuardResult> check(LinkMatch link) async {
    if (XAuthStore.instance.hasToken) return GuardResult.allow();

    // Keep the link; the app calls NotificationLinks.instance.release() after sign-in.
    NotificationLinks.instance.holdLink(link);
    await Get.offAllNamed(AppRoutes.login);
    return GuardResult.stop();
  }
}
```

A link queued with `holdLink` stays queued until `release()` or `discard()`;
it replays with its original `source` and `data`.

### Feature guard — upgrade prompt instead of a dead page

```dart
// lib/app/core/notification_links/guards/feature_guard.dart
class FeatureGuard extends LinkGuard {
  FeatureGuard(this.isEnabled);

  final bool Function() isEnabled;

  @override
  Future<GuardResult> check(LinkMatch link) async {
    if (isEnabled()) return GuardResult.allow();

    await Get.toNamed(AppRoutes.upgrade);
    return GuardResult.stop();
  }
}
```

Attach guards on a class or on the closure shortcut:

```dart
class OrderTrackingLink extends LinkHandler {
  @override
  String get pattern => 'orders/{id:int}/tracking';

  @override
  List<LinkGuard> get guards => [
        FeatureGuard(() => Get.find<PlanService>().hasLiveTracking),
      ];

  @override
  Future<void> handle(LinkMatch link) =>
      Get.toNamed(AppRoutes.orderTracking, arguments: {'id': link.int('id')});
}

LinkRoute(
  'reports/monthly',
  (_) => Get.toNamed(AppRoutes.monthlyReport),
  guards: [FeatureGuard(() => Get.find<PlanService>().hasReports)],
),
```

Guards every route needs (e.g. `SignedInGuard`) go on the config instead:
`guards` on `NotificationLinkConfig` runs before each route's own guards. A
route that must work signed out sets `public: true`.

## Event routes

Push payloads carry a `type` and data. An event handler runs first; when none
matches, the router falls back to `data[linkKey]` through `handle()`. Same two
styles as path routes:

```dart
abstract class EventHandler {
  Set<String> get types;
  Map<String, LinkParam> get require => const {};        // skipped unless present and valid
  Map<String, List<String>> get aliases => const {};     // older key names for the same field
  List<LinkGuard> get guards => const [];
  Future<bool> canHandle(LinkMatch event) async => true;
  Future<void> handle(LinkMatch event);
}
```

Closure:

```dart
EventRoute(
  types: {'PLAN_EXPIRED'},
  action: (_) => Get.toNamed(AppRoutes.upgrade),
),
```

Class — reuses the path handler's logic:

```dart
// lib/app/core/notification_links/events/order_event.dart
class OrderEvent extends EventHandler {
  @override
  Set<String> get types => {'ORDER_CONFIRMED', 'ORDER_SHIPPED', 'ORDER_DELIVERED', 'ORDER_CANCELLED'};

  @override
  Map<String, LinkParam> get require => {'order_id': LinkParam.int};

  @override
  Map<String, List<String>> get aliases => {'order_id': ['orderId']};

  @override
  Future<void> handle(LinkMatch event) async {
    // A cancelled order has nothing left to act on — say so instead of opening it.
    if (event.data['type'] == 'ORDER_CANCELLED') {
      AppSnackbar.info('Order #${event.int('order_id')} was cancelled.');
      return;
    }
    await OpenOrderLink.openOrder(event.int('order_id'));
  }
}
```

## Errors

A handler or guard that throws is caught by the router and passed to
`NotificationLinkConfig.onError` (log, crash reporter). `handle()` then returns
false. The link is not retried and no other route runs.

## Testing a handler class

A handler is a plain class, so it is tested without the router:

```dart
test('payment link opens the receipt when already paid', () async {
  Get.put<PaymentService>(FakePaymentService(paid: true));
  final link = LinkMatch.fromUri(
    Uri.parse('shop://payments/REF-1'),
    pattern: 'payments/{reference}',
  );

  await PaymentLink().handle(link);

  expect(Get.currentRoute, AppRoutes.receipt);
});
```

## Cold-start hold

A push that opens the app from terminated must not navigate before the splash
screen has built the stack — its `offAllNamed` would wipe it. While held,
`handle()` and `handleEvent()` queue the latest link instead of running it.

```
app start ── hold() ── push tap arrives ── queued
          splash routes to home ── release() ── queued link runs
          splash routes elsewhere ── discard() ── queued link dropped
```

`PushNotifications` does not stash its own initial message; it hands it to
`NotificationLinks`. Inbox taps never need the hold — the inbox only exists
once the app is running.

## Example — a full route table

```dart
class AppNotificationLinks extends NotificationLinkConfig {
  @override
  String get scheme => 'shop';

  @override
  List<LinkGuard> get guards => [SignedInGuard()];

  @override
  List<LinkHandler> get routes => [
    LinkRoute('/',                                   (_) => Get.toNamed(AppRoutes.home)),
    LinkRoute('orders',                              (_) => Get.toNamed(AppRoutes.orders)),
    LinkRoute('orders/history',                      (_) => Get.toNamed(AppRoutes.orderHistory)),
    LinkRoute('{kind:invoices|receipts}/{reference}', (link) => Get.toNamed(AppRoutes.receipt,
                                                         arguments: {'reference': link.param('reference')})),
    LinkRoute('chat/**',                             (_) => Get.toNamed(AppRoutes.conversations)),
    LinkRoute('help/**',                             (_) => Get.toNamed(AppRoutes.help), public: true),
    OpenOrderLink(),
    OrderTrackingLink(),
    PaymentLink(),
    OpenConversationLink(),
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

Bind it during boot, before `PushNotifications`:

```dart
NotificationLinks.bind(AppNotificationLinks());
```

### Suggested app layout

One class per file:

```
lib/app/core/notification_links/
  app_notification_links.dart      route table (NotificationLinkConfig)
  links/                           LinkHandler classes
    open_order_link.dart
    order_tracking_link.dart
    payment_link.dart
    open_conversation_link.dart
  events/                          EventHandler classes
    order_event.dart
  guards/                          LinkGuard classes
    signed_in_guard.dart
    feature_guard.dart
```

## Migration from a `switch (segments.first)` handler

| Before | After |
|---|---|
| `case 'x': if (segments[1] == 'y')` | `LinkRoute('x/y', …)` |
| `int.tryParse(segments[1])` + null check | `{id:int}` |
| `case 'a': case 'b':` alias | `{kind:a\|b}` |
| `segments.length >= 2 ? … : null` | `{section?}` |
| unmatched second segment silently ignored | add `x/**` to land on the parent page |
| hand-built `[uri.host, ...uri.pathSegments]` | done by the router |
| a `case` with more than a page push | a `LinkHandler` class in `links/` |
| sign-in / feature checks inside a case | `guards` |

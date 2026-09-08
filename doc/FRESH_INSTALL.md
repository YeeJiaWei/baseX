# Fresh-install detection

Fresh-install detection is a framework-level, process-wide fact: `XInstallMarker` decides
once, for the whole process, whether this launch is the first after a (re)install, and
memoises that answer so every hook that asks agrees — regardless of which one asks first.

There are two hook points. Pick whichever fits what your code needs to touch.

| Hook | Runs | Available inside | Use for |
|------|------|-------------------|---------|
| Driver `onFreshInstall()` | During `XAuthStore.bind()`, before `runXApp` | Prefs / secure storage only | Token + auth-adjacent state |
| `runXApp(onFreshInstall: ...)` | After providers boot, before `runApp` | GetX / services / theme available | Anything else — analytics first_open, resetting hint versions, clearing caches, seeding defaults |

Both hooks read the same process-wide `XInstallMarker.instance`, so a fresh install is fresh
for both no matter which one runs first (see [Why they agree](#why-they-agree) below).

## Driver hook — `onFreshInstall()`

`XAuthStore.bind()` wires this into the boot sequence:

1. `hydrate()` loads the cached token from the backing store
2. If `purgeOnFreshInstall` is true (the default): `XInstallMarker.instance.whenFresh(store.onFreshInstall)` —
   runs `store.onFreshInstall()` only if the marker says fresh, then marks the install seen
3. The store instance is registered as the singleton

Extend the driver class you use (normally `SecureAuthDriver`) and override `onFreshInstall()`:

```dart
class MyAuthDriver extends SecureAuthDriver {
  @override
  Future<void> onFreshInstall() async {
    await super.onFreshInstall();  // must call super first, clears token
    // Your code here — prefs / secure storage only
  }
}
```

**Rule:** the override is `@mustCallSuper` — call `super.onFreshInstall()` before your own
code, since the parent clears the token and runs framework logic.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await XAuthStore.bind(MyAuthDriver());
  await runXApp(...);
}
```

At this point in boot, GetX bindings haven't run, `defaultService` and other app services
aren't injected yet, there's no theme, no router, no `BuildContext`. Whatever your override
reads must be set up before `bind()` — e.g. if you call `S.setTokenAbility(null)`, `S` must
already be assigned.

### Example: clearing extra app state

```dart
class MetaxyAuthDriver extends SecureAuthDriver {
  @override
  Future<void> onFreshInstall() async {
    await super.onFreshInstall();  // clears the token
    await S?.setTokenAbility(null);
  }
}
```

## `runXApp` hook — `onFreshInstall`

Runs once `runXApp`'s providers have booted — GetX, `defaultService`, the theme provider are
all available, same as anywhere else in the widget tree's setup path. Use this for anything
that isn't token/auth cleanup: firing a first-open analytics event, resetting a hint or
tutorial version, clearing caches, seeding local defaults.

```dart
await runXApp(
  ...,
  onFreshInstall: () async {
    Analytics.recordEvent('app_fresh_install');
    await XHint.resetAll();
  },
);
```

An app with no auth store at all can just use this hook — no need to bind a dummy driver
subclass for it.

## Why they agree

Both hooks ask the same `XInstallMarker.instance`. `isFreshInstall` is computed once per
process and memoised — the first hook to ask reads SharedPreferences and caches the answer;
every later ask (from the *other* hook, or a second call from the same hook) gets the cached
answer instead of re-reading. So even though `XAuthStore.bind()` runs before `runXApp` and
marks the install seen first, `runXApp`'s `onFreshInstall` still sees "fresh" for this launch
— the memoised answer, not the persisted flag, is what both hooks act on.

## Custom install marker key

Configure the process-wide marker once, before `bind()` / `runXApp`:

```dart
XInstallMarker.configure(XInstallMarker(key: 'my_existing_install_marker'));
```

`XAuthStore.bind(..., installMarker: someMarker)` also calls `XInstallMarker.configure` for
you, so the rest of the process picks up the same key.

**Warning:** an app migrating from its own hand-rolled marker must pass the **existing key**
(or keep the same key some other way) — a key mismatch makes every already-installed user's
next cold start look fresh, purging their live session and logging everyone out on the next
app update. See [AUTH.md](AUTH.md) for the full warning.

## Failure semantics

**Driver hook:** the marker is set only after the hook resolves. If your override throws, the
marker is not set (next cold start retries it), and the exception also escapes `bind()` —
`main()` crashes and the app fails to start. Wrap non-essential work (analytics, network
calls) in try/catch inside the override, and never await something that can hang.

```dart
@override
Future<void> onFreshInstall() async {
  await super.onFreshInstall();
  try {
    await Analytics.recordEvent('app_fresh_install');
  } catch (e) {
    // Silently continue — analytics failure should never block boot
  }
}
```

**`runXApp` hook:** a thrown exception is caught internally and logged via
`XLogger.error('onFreshInstall failed: $e')` — boot never hangs or crashes on it. The marker
is still set afterwards either way (including when `onFreshInstall` is null at all — an app
with no auth store and no handler still gets the marker written, so a later feature that adds
one starts from a correct state).

## Turning it off

### Disable the driver hook

Pass `purgeOnFreshInstall: false` to `bind()`:

```dart
await XAuthStore.bind(SecureAuthDriver(), purgeOnFreshInstall: false);
```

This skips the marker check and the driver hook entirely — use for tests, tooling, or apps
with nothing to leak. The `runXApp` hook is unaffected; it doesn't take a similar flag since
its handler is simply omitted when unwanted.

## Testing

Reset both the marker and the auth store between tests:

```dart
setUp(() {
  XAuthStore.reset();
  XInstallMarker.reset();
});

tearDown(() {
  XAuthStore.reset();
  XInstallMarker.reset();
});
```

Mock the backing storage, then assert your side effect:

```dart
test('onFreshInstall clears extra app state', () async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});

  await XAuthStore.bind(MyAuthDriver());

  expect(await S?.getTokenAbility(), isNull);
});

test('onFreshInstall does not fire on returning user', () async {
  SharedPreferences.setMockInitialValues({'install_marker': true});
  FlutterSecureStorage.setMockInitialValues({});

  await XAuthStore.bind(MyAuthDriver());

  expect(await S?.getTokenAbility(), isNotNull);
});
```

`XInstallMarker` itself can be tested directly too — `isFreshInstall`, `markSeen()` and
`whenFresh()` don't need `XAuthStore` at all:

```dart
test('whenFresh runs the handler once and marks seen', () async {
  SharedPreferences.setMockInitialValues({});
  final marker = XInstallMarker();
  var calls = 0;

  await marker.whenFresh(() async => calls++);

  expect(calls, 1);
  expect(await marker.isFreshInstall, isTrue); // memoised, not re-read
});
```

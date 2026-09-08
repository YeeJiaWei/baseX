# Auth — `XAuthStore`

The bearer token is framework state. `AuthInterceptor` reads it from the bound
`XAuthStore`, not from shared preferences.

## Contract

The cache and its normalisation (empty string → null) live in `XAuthStore`
itself — a driver only implements `read` / `write` / `delete`, pure
persistence with no caching of its own.

```dart
abstract class XAuthStore {
  String? get cachedToken;          // sync, in-memory; null when logged out
  Future<String?> readToken();      // bypasses the cache, reads via the driver
  Future<void> setToken(String? t); // null / '' clears; writes via the driver, updates the cache
  Future<void> hydrate();           // loads the cache by reading via the driver
  bool get hasToken;

  // Lifecycle (see below)
  Future<void> signIn(String token, {Map<String, Object?> meta});
  Future<void> signOut({Future<void> Function()? remote});
  Future<void> onFreshInstall();    // runs once on first launch after a (re)install
  Future<void> onSignedIn(Map<String, Object?> meta, {String? previousToken});
  Future<void> onSignedOut();
  Future<void> onUnauthorized();

  static Future<T> bind<T extends XAuthStore>(
    T store, {
    bool purgeOnFreshInstall = true,
    XInstallMarker? installMarker,
  });
  static XAuthStore get instance;      // throws before bind()
  static XAuthStore? get maybeInstance;

  @protected Future<String?> read();     // driver hook — persistence only
  @protected Future<void> write(String token);
  @protected Future<void> delete();
}
```

### Writing a driver

Extend `XAuthStore` and implement `read`, `write` and `delete` only — do not
cache or normalise the token yourself; the base class does both. `read`
should return null (not throw) for "nothing stored"; anything else the driver
can't recover from should also resolve to null rather than propagate, since
`bind()` awaits `hydrate()` during boot (see `SecureAuthDriver`'s
BadPadding/BAD_DECRYPT recovery below).

Two drivers ship with baseX:

| Class | Backing | Use |
|-------|---------|-----|
| `SecureAuthDriver` | `flutter_secure_storage` (Keychain / Keystore) | apps |
| `InMemoryAuthDriver` | none | tests, tooling |

`SecureAuthDriver`'s key defaults to `bearer_token`. Do not change it on an
existing app — the key *is* the migration path for installed sessions.

Token *exchange* (login, OTP, refresh) stays in app services; the store only
holds what those services obtain.

## Bind during boot

`bind()` is async, hydrates the cache, and runs the fresh-install purge (see
below); `runXApp` invokes `sharedPref()` synchronously and takes no store
parameter, so bind before calling it — and in any case before the first
authenticated request.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await XAuthStore.bind(SecureAuthDriver());
  await runXApp(...);
}
```

## Lifecycle

The store owns the whole token lifecycle; app code supplies only the domain
steps, as driver overrides.

```
bind() → (onFreshInstall) → signIn() → onSignedIn()
       → authenticated requests
       → onUnauthorized()            (server rejected the token, 401)
       | signOut() → onSignedOut()   (user asked to leave)
```

After a login response:

```dart
await XAuthStore.instance.signIn(
  response.token,
  meta: {'ability': response.ability, 'userId': response.user.id},
);
```

`signIn` stores the token, then calls `onSignedIn(meta, previousToken:)`.
`meta` is whatever the app needs to persist alongside the token; `previousToken`
is what was cached before the write (null on a first sign-in), so a driver can
tell a re-issue from a fresh login.

Logout:

```dart
await XAuthStore.instance.signOut(remote: authService.logout);
```

`signOut` calls `remote` first — best effort, only when a token is actually
held, and a throw is logged and swallowed — then clears the token and calls
`onSignedOut()`.

### 401 → `onUnauthorized`

`ApiErrorInterceptor` raises `onUnauthorized()` automatically when a request
that opted into auth (`requiredToken: true`) comes back `401`, after the error
is mapped to `UnauthorizedException` and before the failure is handed back to
the caller. It fires only when the bearer that was actually sent on the request
still equals `cachedToken`, so a response that failed with an already-replaced
token can never wipe a newer one. The default implementation clears the token;
app code should not clear it again.

In envelope mode (`required200: true`) the server reports the rejection as HTTP
200 with `code: 401` in the body; that path is rejected from `onResponse`, which
raises the same hook before rejecting.

### A driver overriding all three

```dart
class MetaxyAuthDriver extends SecureAuthDriver {
  @override
  Future<void> onSignedIn(Map<String, Object?> meta, {String? previousToken}) async {
    await super.onSignedIn(meta, previousToken: previousToken);
    await S?.setTokenAbility(meta['ability'] as String?);
    await S?.setUserId(meta['userId'] as int?);
  }

  @override
  Future<void> onSignedOut() async {
    await super.onSignedOut();
    await S?.setTokenAbility(null);
    await S?.setSubscriptionTier(null);
  }

  @override
  Future<void> onUnauthorized() async {
    await super.onUnauthorized();
    await S?.setTokenAbility(null);
  }
}
```

`setToken` is still there for the low-level case, but prefer the lifecycle
methods — they are what keeps the app's token metadata in step.

## Fresh-install purge

iOS keeps Keychain items after the app is deleted, so a token can outlive an
uninstall and silently resume the previous session. SharedPreferences *is*
wiped on uninstall, so the absence of an install marker is a reliable
fresh-install signal.

`bind()` runs this automatically: when `purgeOnFreshInstall` is true (the
default) and the marker isn't set yet, it calls `store.onFreshInstall()` —
which clears the token by default — then sets the marker. Nothing extra is
required for the common case:

```dart
await XAuthStore.bind(SecureAuthDriver());
```

To clear additional app state (e.g. a cached token ability), override
`onFreshInstall()` in a driver subclass, calling `super`:

```dart
class MetaxyAuthDriver extends SecureAuthDriver {
  @override
  Future<void> onFreshInstall() async {
    await super.onFreshInstall();
    await S?.setTokenAbility(null);
  }
}
```

This is one of two fresh-install hooks — the other, `runXApp(onFreshInstall: ...)`, runs
after providers boot (GetX/services/theme available) for anything beyond auth cleanup. See
[FRESH_INSTALL.md](FRESH_INSTALL.md) for the full guide: both hooks, what's available inside
each, failure semantics, and testing patterns.

To opt out of the automatic purge (e.g. `InMemoryAuthDriver` in tests where
there's nothing to leak), pass `purgeOnFreshInstall: false`:

```dart
await XAuthStore.bind(InMemoryAuthDriver(), purgeOnFreshInstall: false);
```

The marker itself is `XInstallMarker`, backed by `SharedPreferences`, keyed
`install_marker` by default. It's a process-wide singleton (`XInstallMarker.instance`) with a
memoised answer, so it agrees with the `runXApp(onFreshInstall: ...)` hook regardless of which
one asks first — see [FRESH_INSTALL.md](FRESH_INSTALL.md#why-they-agree):

```dart
class XInstallMarker {
  XInstallMarker({this.key = 'install_marker'});
  static XInstallMarker get instance;
  static void configure(XInstallMarker marker);
  Future<bool> get isFreshInstall;
  Future<void> markSeen();
  Future<void> whenFresh(Future<void> Function() handler);
}
```

Pass a custom instance via `bind(..., installMarker: XInstallMarker(key: '...'))`
if an app already tracks its own marker under a different key — this also configures the
process-wide instance, so `runXApp`'s hook picks up the same key.

> **Warning:** an app migrating from its own hand-rolled install marker must
> pass `installMarker: XInstallMarker(key: '<existing key>')` (or otherwise
> keep the same key) — a key mismatch makes `bind()` treat every already-installed
> user's next cold start as a fresh install and purge their live session,
> logging everyone out on update.

## Migration

| Before | After |
|--------|-------|
| `X!.accessToken` (read) | `XAuthStore.instance.cachedToken` |
| `X!.accessToken = token` | `await XAuthStore.instance.signIn(token, meta: {...})` |
| `X!.accessToken = null` on logout | `await XAuthStore.instance.signOut(remote: ...)` |
| Manual `POST /logout` then clear | `signOut(remote: authService.logout)` |
| App-side "persist ability / user id after login" | driver `onSignedIn(meta, previousToken:)` |
| App-side "clear app state on logout" | driver `onSignedOut()` |
| App-side 401 handler clearing the token | automatic; driver `onUnauthorized()` for extra state |
| `if (X!.accessToken.isNotEmpty)` | `XAuthStore.instance.hasToken` |
| App-side `SecureAuthStore.bind(...)` | `XAuthStore.bind(SecureAuthDriver())` |
| App-side `purgeTokenOnFreshInstall(pref, store)` | automatic in `bind()`; override `onFreshInstall()` for extra state |

`BaseXSharePref.accessToken` is deprecated but still present: when no store is
bound, `AuthInterceptor` falls back to it so unmigrated apps keep working.

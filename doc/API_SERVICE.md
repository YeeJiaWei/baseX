# API Service — connections, providers, and services

How the baseX HTTP layer is wired since the multi-connection redesign. The
short version: **one `ApiXService` subclass = one connection**, connections
are declared as **alias → factory** by an **`ApiXServiceProvider`**, built
lazily by the **`ApiXConnections`** registry, and every service class picks
its connection through a **project-level service base**.

```
ApiXServiceProvider ──declares──▶ ApiXConnections (alias → factory, lazy)
                                        │ of(alias)
                                        ▼
ServiceMixin base (per connection) ──▶ ApiXService subclass instance
        ▲
        └──extends── service classes
```

## 1. Define a connection

`ApiXService` is abstract, builds its own `Dio` internally, and contributes
**no interceptors of its own** — the stack is composed from **trait mixins**,
each appending its interceptor via `[...super.interceptors, TheInterceptor()]`.
Order in the `with` clause = order in the stack.

baseX ships one trait per built-in — `DeviceHeaderApiMixin`, `AuthApiMixin`,
`ApiErrorApiMixin`, `XLoggerApiMixin`, `UserSyncApiMixin` — plus
**`StandardApiXService`**, the pre-composed standard stack (device headers →
auth → error mapping → logging). An ordinary app connection extends it and
adds only its own traits (the bearer token `AuthApiMixin` attaches comes from
the bound `XAuthStore` — see [AUTH.md](AUTH.md)):

Tests can script the transport with
`service.httpClientAdapter = <HttpClientAdapter>` (`@visibleForTesting`), which
swaps the client under the real interceptor stack.

```dart
class MyAppApiService extends StandardApiXService with UserSyncApiMixin {
  // REQUIRED — which host to talk to is application policy (your env/flavor
  // system decides), not framework structure.
  @override
  String get endpoint => MyEnv.apiBaseUrl;

  @override
  XUserSyncInterceptor get userSyncInterceptor => MyUserSyncInterceptor();

  // Optional overrides. Defaults:
  // Duration get timeout  => timeoutDuration; // 60s
  // BaseXHttp get http    => DefaultBaseXHttp();
}
```

The getters are read **once, during construction** — keep overrides constant.

- `http` — per-connection status-code mapping (`BaseXHttp` subclass). There is
  no shared global anymore; each connection's error mapping is its own.
- A one-off interceptor without a trait chains the same way at class level:
  `List<Interceptor> get interceptors => [...super.interceptors, MyOnceOff()];`
- A connection to a **foreign API** that must not carry the app token / device
  headers, or that doesn't return the `{message, data}` envelope (the
  `ApiErrorApiMixin` mapping assumes that shape), skips `StandardApiXService`
  and composes from `ApiXService` directly:

```dart
class WeatherApiService extends ApiXService with XLoggerApiMixin {
  @override
  String get endpoint => 'https://api.weather.example';
}
```

`DefaultApiXService(endpoint)` is the concrete `StandardApiXService` (standard
traits only, endpoint passed in) — use it as a plain second connection when
some endpoints must skip the default connection's app traits, or as the
default connection of an app with nothing to add.

## 2. Register connections — `ApiXServiceProvider` + `ApiXConnections`

Connections are declared in the provider list (`AppConstant.providerConfig`),
not in `runXApp` parameters. The provider registers **factories by alias**
into the `ApiXConnections` registry; the default goes under
`ApiXConnections.defaultAlias` (`'default'`) and is what the global
`defaultService` resolves to:

```dart
class AppApiServiceProvider extends ApiXServiceProvider {
  @override
  ApiXService buildDefault() => MyAppApiService();

  @override
  Map<String, ApiXService Function()> get connections => {
        'weather': WeatherApiService.new,
      };
}
```

```dart
class AppProviders extends ProviderConfig {
  @override
  List<ServiceProvider> get providers => [
        AppApiServiceProvider(),
        // ...
      ];
}
```

Access anywhere by alias — Laravel's `DB::connection('x')`:

```dart
final res = await ApiXConnections.of('weather').get('forecast', requiredToken: false);
```

- **Lazy** — a factory only runs on the alias's first `of()` access, so no
  connection sits on standby (including the default: `defaultService` builds
  on the first API call).
- **Duplicate aliases throw** — one definition per connection.
- **An `ApiXServiceProvider` is required** — `runXApp` does no API wiring of
  its own. Without one, the first `defaultService` /
  `ApiXConnections.of(...)` access throws a `StateError` naming the missing
  registration. An app with no interceptors of its own just returns a bare
  `DefaultApiXService` from `buildDefault()`.

### Lifecycle / dispose

A long-lived app connection should just stay registered — an idle client
costs almost nothing, and keeping it preserves keep-alive connections. For
short-lived one-offs (payment gateway, a large download from another host):

```dart
ApiXConnections.dispose('payment'); // closes the client AND evicts it
```

The alias stays registered, so the next `of('payment')` rebuilds a fresh
instance from its factory. `ApiXService.dispose()` exists too, but prefer the
registry call — it does close + evict together. Don't dispose an alias with
requests still in flight unless you pass `force: true` and mean it.

## 3. Service classes

`ApiServiceMixin` declares two abstract getters — a service must state its
transport and path; there is no implicit default. Define **one project base
per connection** and extend it:

```dart
/// All services on the default connection.
abstract class MyAppService with ApiServiceMixin {
  @override
  ApiXService get defaultServ => defaultService;
}

/// Services on the weather connection.
abstract class WeatherService with ApiServiceMixin {
  @override
  ApiXService get defaultServ => ApiXConnections.of('weather');
}

class BannerService extends MyAppService {
  @override
  String apiPath = 'banners';

  Future<BannerModel?> getCurrent() async {
    final res = await defaultServ.get('$apiPath/current', requiredToken: false);
    return res.toObject(BannerModel.fromJson);
  }
}
```

## 4. User sync — `XUserSyncInterceptor`

Checksum-based auto refresh of the cached session user on every authed
request. baseX owns the transport half; the app owns the application half; the
server owns the compare-and-attach half.

**Contract**

- Request: the client sends its last received checksum as `X-User-Checksum`
  on requests with `requiredToken: true` (no header on fresh launch).
- Response: when the server-side checksum differs, the server attaches two
  siblings **next to** the envelope: `{message, data, user, user_checksum}`.
  On match it attaches nothing.
- The checksum is server-computed; the client stores it verbatim and never
  recomputes it.

**App half** — extend the base with storage/apply logic, then attach it to
the connection with the `UserSyncApiMixin` trait (see §1):

```dart
class MyUserSyncInterceptor extends XUserSyncInterceptor {
  @override
  String? get currentChecksum => mySession.userChecksum;

  @override
  void applySyncedUser(Map<String, dynamic> userJson, String checksum) {
    mySession.apply(User.fromJson(userJson), checksum);
  }
}
```

Overridable knobs: `checksumHeader`, `userKey`, `checksumKey`. Apply failures
are swallowed by the base — a sync problem never breaks the carrying request.

**Server half** — a response middleware that, for authenticated 2xx JSON
responses, builds the user payload, computes `md5(json_encode(payload))`,
compares it with the `X-User-Checksum` header, and adds `user` +
`user_checksum` to the (already-wrapped) envelope on mismatch. It must run
*after* the envelope middleware on the response path, or the envelope drops
the sibling keys.

## 5. Making requests

Verbs live on `ApiXService` (`get`, `post`, `put`, `delete`) and every one
returns the raw dio `Response?` — **not** a model. It is `null` when the
request failed (the callbacks already ran), the `Response` on 2xx. Failures
are swallowed into `null`; a verb never throws, so don't wrap it in try/catch.
Deserialise at the call site with the null-safe `Response?` extensions:

| Extension | Result |
| --- | --- |
| `res.toObject(Model.fromJson)` | `T?` from the envelope's `data` map |
| `res.toList(Model.fromJson)` | `List<T>?` from the envelope's `data` list |
| `res.xMessage` | envelope `message`, `''` when absent |

- `endpoint` has no leading slash (`'banners'`); `pathParam` is appended as `/id`.
  `delete` takes the `pathParam` as its second positional argument.
- `queryParam` is `JSON` (`Map<String, dynamic>`).

### Callbacks

| Callback | Fires on | Argument |
| --- | --- | --- |
| `onSuccess(Response)` | 2xx | the response |
| `onError(Response)` | 4xx/5xx (a response was received) | the response, never null |
| `onTimeout()` | no response: timeout or dropped connection | none |
| `onComplete(Response?)` | always, after the above | the response, or null |

There is no positional failure callback. To learn the cause, read it in
`onError` / `onTimeout`.

### Token

`requiredToken` defaults to **true**: `AuthApiMixin` attaches
`Authorization: Bearer <XAuthStore.cachedToken>`. Pass `requiredToken: false`
for login, OTP, public content and foreign APIs. A 401 on a `requiredToken:
true` call clears the token automatically (see [AUTH.md](AUTH.md)).

### Request bodies

- **`post`** sends `FormData.fromMap(body, ListFormat.multiCompatible)`: list
  values are bracket-encoded for you (`genders[]=f&genders[]=m`). Post plain
  Lists, usually straight from `toJson()`; do not pre-encode keys like
  `'genders[]'` or `'genders[0]'`. Nested maps are not flattened — keep bodies
  one level deep or send id lists.
- FormData **stringifies every value** (`1` → `"1"`, `true` → `"true"`). Coerce
  on the server, and cast deliberately when storing into a JSON/key-value column.
- **`put`** passes the map straight to dio, so it is a JSON body — not
  multipart, and lists are not bracket-encoded. Use it only for endpoints that
  expect JSON; for create/update where the server reads form fields, use `post`.
  There is no `patch` verb.

### Errors

`ApiErrorInterceptor` maps failures to `XError` subclasses (extending
`DioException`) using the connection's `BaseXHttp` mapping:

| Status (default) | Class |
| --- | --- |
| 400 | `InvalidRequestException` |
| 401 | `UnauthorizedException` |
| 404 | `NotFoundException` |
| 409 | `VersionOutdateException` |
| 422 | `ValidationException` |
| 426 | `ForceUpdateException` |
| 429 | `TooManyRequestException` |
| 500 | `InternalServerErrorException` |
| 503 | `MaintenanceException` |
| timeouts | `TimeOutException`; no connection: `NoConnectionException` |

Callbacks receive the `Response`, not the exception: branch on
`r.statusCode` and read `r.xMessage`. 422 validation errors sit in the response
body (`r.data`). Override codes per connection with a `BaseXHttp` subclass
returned from the connection's `http` getter. With `runXApp(required200: true)`
a 2xx body with `code >= 200` and a falsy `status` is treated as a failure and
routed to `onError`.

### Timeouts

`timeout` (default 60s) is the **connect** timeout. Timeouts and dropped
connections land in `onTimeout`, and the verb returns `null`.

## 6. Migration from the old API

| Before | After |
| --- | --- |
| `ApiXService.init(dio, timeout, customHttp: …)` | subclass `ApiXService`, override getters |
| `runXApp(customHttp: …)` | `BaseXHttp get http` on the connection |
| `runXApp(timeOutDurationInSecond: …)` | `Duration get timeout` on the connection |
| `runXApp(apiServiceBuilder: …)` | `ApiXServiceProvider.buildDefault()` |
| global `baseXHttp` | removed — `ApiErrorInterceptor` carries its connection's `BaseXHttp` |
| second connection: not supported | subclass + alias in the provider's `connections` map |
| eager `defaultService` at startup | lazy — built by `ApiXConnections` on first API call |
| endpoint defaulted to `kDebugMode ? uatBaseUrl : baseUrl` | `endpoint` is abstract — the app's env/flavor system decides |

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:baseX/Core/logger/x_logger.dart';
import 'package:baseX/Core/push/push_notifications.dart';
import 'package:baseX/Core/storage/x_install_marker.dart';

/// Framework contract for where the API bearer token lives, plus the token
/// lifecycle the app hooks into.
///
/// The store owns the in-memory cache so the dio `AuthInterceptor` can read
/// the token synchronously without an async round-trip to the backing store.
/// A driver only implements [read], [write] and [delete] — pure persistence,
/// no caching.
///
/// Lifecycle:
///
/// ```
/// bind() → (onFreshInstall) → signIn() → onSignedIn()
///        → authenticated requests
///        → onUnauthorized()            (server rejected the token, 401)
///        | signOut() → onSignedOut()   (user asked to leave)
/// ```
///
/// A driver subclass overrides [onSignedIn], [onSignedOut] and
/// [onUnauthorized] (each calling `super`) to persist or clear the app's own
/// token metadata — ability, user id, cached plan — so app code only supplies
/// the domain steps. Token *exchange* (login, OTP, refresh) stays in app
/// services; the store only holds what those services obtain.
abstract class XAuthStore {
  static XAuthStore? _instance;

  /// The bound store; throws when [bind] has not run yet.
  static XAuthStore get instance {
    final store = _instance;
    if (store == null) {
      throw StateError('XAuthStore.instance accessed before bind()');
    }
    return store;
  }

  /// The bound store, or null when nothing has been bound.
  static XAuthStore? get maybeInstance => _instance;

  /// Hydrates [store] from its backing storage, purges it on a fresh (re)install
  /// unless [purgeOnFreshInstall] is false, then registers it as the singleton.
  ///
  /// iOS keeps Keychain items after the app is deleted, so a secure-store token
  /// can outlive an uninstall and silently resume the previous session.
  /// [installMarker] tracks first launch via SharedPreferences, which *is*
  /// wiped on uninstall, so its absence is a reliable fresh-install signal.
  /// Defaults to [XInstallMarker.instance]; passing a custom marker also
  /// [XInstallMarker.configure]s it, so `runXApp`'s `onFreshInstall` hook
  /// agrees with this one on whether the install is fresh.
  static Future<T> bind<T extends XAuthStore>(
    T store, {
    bool purgeOnFreshInstall = true,
    XInstallMarker? installMarker,
  }) async {
    await store.hydrate();

    if (purgeOnFreshInstall) {
      final marker = installMarker ?? XInstallMarker.instance;
      if (installMarker != null) XInstallMarker.configure(installMarker);
      await marker.whenFresh(store.onFreshInstall);
    }

    _instance = store;
    return store;
  }

  /// Drops the bound singleton.
  @visibleForTesting
  static void reset() => _instance = null;

  String? _cachedToken;

  /// In-memory copy of the persisted token; null when logged out.
  String? get cachedToken => _cachedToken;

  /// Loads the cache from the driver.
  Future<void> hydrate() async => _cachedToken = _normalise(await read());

  /// Persists the token through the driver and updates the cache; null or empty clears.
  Future<void> setToken(String? token) async {
    final value = _normalise(token);
    if (value == null) {
      await delete();
    } else {
      await write(value);
    }
    _cachedToken = value;
  }

  /// Stores a freshly issued token and runs [onSignedIn].
  Future<void> signIn(String token, {Map<String, Object?> meta = const {}}) async {
    final previousToken = cachedToken;
    await setToken(token);
    await onSignedIn(meta, previousToken: previousToken);
    unawaited(PushNotifications.maybeInstance?.refreshRegistration());
  }

  /// Best-effort push unregister and [remote] revoke call, then clears the token and runs [onSignedOut].
  Future<void> signOut({Future<void> Function()? remote}) async {
    if (hasToken) await PushNotifications.maybeInstance?.unregisterCurrentToken();
    if (remote != null && hasToken) {
      try {
        await remote();
      } catch (e) {
        XLogger.error('signOut remote failed (swallowed): $e');
      }
    }
    await setToken(null);
    await onSignedOut();
  }

  /// Runs after a token is stored; override to persist token metadata, calling super.
  @mustCallSuper
  Future<void> onSignedIn(Map<String, Object?> meta, {String? previousToken}) async {}

  /// Runs after the token is cleared on sign-out; override to clear app state, calling super.
  @mustCallSuper
  Future<void> onSignedOut() async {}

  /// Runs when the server rejects the current token (401); clears it by default.
  /// Override to drop derived app state too, calling super.
  @mustCallSuper
  Future<void> onUnauthorized() => setToken(null);

  /// Reads straight from the driver, bypassing the cache.
  Future<String?> readToken() async => _normalise(await read());

  /// Whether a usable token is currently cached.
  bool get hasToken => cachedToken?.isNotEmpty ?? false;

  /// Runs once on the first launch after a (re)install; override to clear
  /// extra app state, calling super.
  @mustCallSuper
  Future<void> onFreshInstall() => setToken(null);

  /// Reads the persisted token from the backing storage.
  @protected
  Future<String?> read();

  /// Persists [token] to the backing storage.
  @protected
  Future<void> write(String token);

  /// Removes the persisted token from the backing storage.
  @protected
  Future<void> delete();

  String? _normalise(String? token) => (token == null || token.isEmpty) ? null : token;
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Process-wide fresh-install fact, memoised so every caller — the auth
/// store's `onFreshInstall` and `runXApp`'s `onFreshInstall` alike — agrees
/// on the answer regardless of which one checks first. Absent on a fresh
/// (re)install because SharedPreferences is wiped with the app while the
/// Keychain is not.
class XInstallMarker {
  XInstallMarker({this.key = 'install_marker'});

  final String key;

  static XInstallMarker _instance = XInstallMarker();

  /// The process-wide marker; configure the key before the first check.
  static XInstallMarker get instance => _instance;

  /// Replaces the process-wide marker; must run before bind() / runXApp.
  static void configure(XInstallMarker marker) => _instance = marker;

  @visibleForTesting
  static void reset() => _instance = XInstallMarker();

  Future<bool>? _isFresh;

  /// True on the first launch after a (re)install; memoised for the process.
  Future<bool> get isFreshInstall => _isFresh ??= _readIsFresh();

  Future<bool> _readIsFresh() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(key) ?? false);
  }

  /// Records that this install has been seen; idempotent.
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  /// Runs [handler] only on a fresh install, then marks the install seen.
  /// Exceptions from [handler] propagate.
  Future<void> whenFresh(Future<void> Function() handler) async {
    if (await isFreshInstall) {
      await handler();
    }
    await markSeen();
  }
}

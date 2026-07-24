import 'package:flutter/foundation.dart';

import 'package:baseX/api_service/client/api_x_service.dart';

/// The app's default connection — built lazily on first access. Throws a
/// [StateError] when no ApiXServiceProvider declared it.
ApiXService get defaultService => ApiXConnections.of(ApiXConnections.defaultAlias);

/// Alias-keyed registry of API connections (Laravel's `DB::connection('x')`).
/// Factories run lazily on first [of] access; [dispose] evicts so an alias
/// rebuilds on next use.
class ApiXConnections {
  ApiXConnections._();

  /// Alias of the default connection ([defaultService]).
  static const String defaultAlias = 'default';

  static final Map<String, ApiXService Function()> _factories = {};
  static final Map<String, ApiXService> _instances = {};

  /// Register a connection factory under [alias]. Duplicates throw.
  static void register(String alias, ApiXService Function() factory) {
    if (_factories.containsKey(alias)) {
      throw StateError("API connection '$alias' is already registered");
    }
    _factories[alias] = factory;
  }

  /// The connection registered under [alias], built on first access.
  static ApiXService of(String alias) {
    final instance = _instances[alias];
    if (instance != null) return instance;

    final factory = _factories[alias];
    if (factory == null) {
      throw StateError(
          "No API connection registered under '$alias'. Declare it in your ApiXServiceProvider.");
    }
    return _instances[alias] = factory();
  }

  /// Whether a factory is registered under [alias].
  static bool contains(String alias) => _factories.containsKey(alias);

  /// Close [alias]'s built instance and evict it; the next [of] rebuilds.
  static void dispose(String alias, {bool force = false}) {
    _instances.remove(alias)?.dispose(force: force);
  }

  /// The registered aliases.
  static List<String> get aliases => _factories.keys.toList();

  /// Clear all factories and built instances (closing them).
  @visibleForTesting
  static void reset() {
    for (final instance in _instances.values) {
      instance.dispose(force: true);
    }
    _instances.clear();
    _factories.clear();
  }
}

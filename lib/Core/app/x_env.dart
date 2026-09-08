import 'package:baseX/base_x.dart';

/// The environment values baseX resolves at boot: the app [name] and
/// [apiBaseUrl] for the active [flavor]. An [XEnv] resolves one of these and is
/// handed to [runXApp] via `env:`, which derives the title + base URLs from it.
abstract class XEnvironment {
  /// The running flavor.
  Flavor get flavor;

  /// App display name / title.
  String get name;

  /// API base URL (e.g. https://.../api/v1).
  String get apiBaseUrl;
}

/// Parses --dart-define=APP_ENV into a [Flavor] (defaults to development).
Flavor flavorFromEnv() {
  const raw = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  switch (raw.toLowerCase()) {
    case 'production':
      return Flavor.production;
    case 'staging':
      return Flavor.staging;
    case 'development':
    default:
      return Flavor.development;
  }
}

/// Resolves the active [XEnvironment] from APP_ENV. Subclass and implement
/// [resolve] to map a flavor to your environment; parsing, lazy holding and
/// logging are handled here. Hand the instance to [runXApp] via `env:`, which
/// reads [active] to derive the title + base URLs.
///
/// ```dart
/// class AppEnv extends XEnv<EnvironmentAppConstant> {
///   @override
///   EnvironmentAppConstant resolve(Flavor flavor) {
///     switch (flavor) {
///       case Flavor.development: return AppConstantDevelopment();
///       case Flavor.staging:     return AppConstantStaging();
///       case Flavor.production:  return AppConstantProduction();
///     }
///   }
/// }
/// ```
abstract class XEnv<T extends XEnvironment> {
  T? _active;

  /// The active environment, lazily resolved from APP_ENV on first access.
  T get active => _active ??= _resolveActive();

  T _resolveActive() {
    final flavor = flavorFromEnv();
    XLogger.info('[XEnv] flavor=${flavor.name}');
    return resolve(flavor);
  }

  /// Maps a flavor to its environment config.
  T resolve(Flavor flavor);
}

import 'package:baseX/base_x.dart';

/// Resolves the active [EnvironmentConstant] from APP_ENV. Subclass and implement
/// [resolve] to map a flavor to your environment; parsing, lazy holding and
/// logging are handled here. Hand the instance to [runXApp] via `env:`, which
/// reads [active] to derive the title + base URLs.
///
/// ```dart
/// class AppEnv extends EnvironmentResolver<EnvironmentAppConstant> {
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
abstract class EnvironmentResolver<T extends EnvironmentConstant> {
  T? _active;

  /// The active environment, lazily resolved from APP_ENV on first access.
  T get active => _active ??= _resolveActive();

  T _resolveActive() {
    final flavor = flavorFromEnv();
    XLogger.info('[EnvironmentResolver] flavor=${flavor.name}');
    return resolve(flavor);
  }

  /// Maps a flavor to its environment config.
  T resolve(Flavor flavor);
}

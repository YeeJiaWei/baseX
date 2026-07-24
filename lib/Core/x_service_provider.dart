import 'package:baseX/base_x.dart';

/// Laravel-style service provider.
///
/// A provider groups the bootstrap logic for one concern (theme, analytics,
/// deep links, …) so the app's entry point stays thin. List providers via a
/// [ProviderConfig] on your AppConstant — the framework runs every [register]
/// first, then every [boot], before building the app.
///
/// - [register]: bind/configure. Do NOT depend on another provider here — it
///   may not have registered yet.
/// - [boot]: runs after all providers are registered; safe to use others.
abstract class ServiceProvider {
  /// Bind and configure this provider's services.
  void register() {}

  /// Run side effects after all providers have registered.
  void boot() {}
}

/// Declares the app's API connections into [ApiXConnections] — the default
/// from [buildDefault] plus any aliases from [connections], all registered as
/// lazy factories. Required in the provider list: nothing else registers
/// connections. See doc/API_SERVICE.md.
abstract class ApiXServiceProvider extends ServiceProvider {
  /// Build the app's default connection ([defaultService]).
  ApiXService buildDefault();

  /// Extra named connections (alias → factory).
  Map<String, ApiXService Function()> get connections => const {};

  @override
  void register() {
    ApiXConnections.register(ApiXConnections.defaultAlias, buildDefault);
    connections.forEach(ApiXConnections.register);
  }
}

/// Holds the app's [ServiceProvider] list — the equivalent of Laravel's
/// `config/app.php` providers array. Subclass and override [providers]:
///
/// ```dart
/// class AppProviders extends ProviderConfig {
///   @override
///   List<ServiceProvider> get providers => [ThemeServiceProvider()];
/// }
/// ```
///
/// Point your `AppConstant.providerConfig` at it; baseX boots the list.
class ProviderConfig {
  const ProviderConfig();

  /// The providers to boot, in order. Defaults to none.
  List<ServiceProvider> get providers => const [];
}


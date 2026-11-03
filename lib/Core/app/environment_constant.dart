import 'package:baseX/base_x.dart';

/// The environment values baseX resolves at boot: the app [name] and
/// [apiBaseUrl] for the active [flavor]. An [EnvironmentResolver] resolves one of these and is
/// handed to [runXApp] via `env:`, which derives the title + base URLs from it.
abstract class EnvironmentConstant {
  /// The running flavor.
  Flavor get flavor;

  /// App display name / title.
  String get name;

  /// API base URL (e.g. https://.../api/v1).
  String get apiBaseUrl;
}

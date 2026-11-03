/// App build flavor, selected via --dart-define=APP_ENV=development|staging|production.
enum Flavor { development, staging, production }

/// Raw --dart-define=APP_ENV value; a compile-time constant so `if (isProduction)` branches fold and the other flavors are tree-shaken from release builds.
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'development');
const bool isProduction = appEnv == 'production';
const bool isStaging = appEnv == 'staging';
const bool isDevelopment = appEnv == 'development';

/// Parses --dart-define=APP_ENV into a [Flavor] (defaults to development when unset).
Flavor flavorFromEnv() => parseFlavor(appEnv);

/// Maps an APP_ENV value to its [Flavor], throwing on anything unrecognised.
///
/// An unknown value (a typo, or a short name like `prod`) must fail at boot:
/// falling back to development would ship a release build against the dev API.
Flavor parseFlavor(String raw) {
  switch (raw.toLowerCase()) {
    case 'production':
      return Flavor.production;
    case 'staging':
      return Flavor.staging;
    case 'development':
      return Flavor.development;
    default:
      throw FormatException(
        'APP_ENV "$raw" is not a flavor; use development, staging or production',
      );
  }
}

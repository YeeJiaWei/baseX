/// App build flavor, selected via --dart-define=APP_ENV=development|staging|production.
enum Flavor { development, staging, production }

/// Parses --dart-define=APP_ENV into a [Flavor] (defaults to development when unset).
Flavor flavorFromEnv() {
  const raw = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  return parseFlavor(raw);
}

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

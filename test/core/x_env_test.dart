import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/index.dart';

void main() {
  test('maps each flavor name, ignoring case', () {
    expect(parseFlavor('development'), Flavor.development);
    expect(parseFlavor('staging'), Flavor.staging);
    expect(parseFlavor('production'), Flavor.production);
    expect(parseFlavor('PRODUCTION'), Flavor.production);
  });

  test('throws on a short or unknown name instead of falling back to development', () {
    for (final raw in ['prod', 'dev', 'stg', 'live', '']) {
      expect(() => parseFlavor(raw), throwsFormatException, reason: raw);
    }
  });

  test('defaults to development when APP_ENV is unset', () {
    expect(flavorFromEnv(), Flavor.development);
  });
}

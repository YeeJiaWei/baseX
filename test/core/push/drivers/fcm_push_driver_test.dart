import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/index.dart';

import 'fake_firebase_messaging.dart';

void main() {
  const expected = {
    AuthorizationStatus.authorized: PushPermission.authorized,
    AuthorizationStatus.provisional: PushPermission.provisional,
    AuthorizationStatus.denied: PushPermission.denied,
    AuthorizationStatus.notDetermined: PushPermission.notDetermined,
  };

  for (final entry in expected.entries) {
    test('maps ${entry.key} from settings and from a request', () async {
      final driver = FcmPushDriver(
        messaging: FakeFirebaseMessaging(entry.key),
      );

      expect(await driver.getPermission(), entry.value);
      expect(await driver.requestPermission(), entry.value);
    });
  }
}

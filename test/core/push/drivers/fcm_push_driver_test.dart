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

  test('maps the payload JSON string and keeps other data keys', () async {
    final messaging = FakeFirebaseMessaging(AuthorizationStatus.authorized)
      ..initialMessage = const RemoteMessage(
        messageId: 'm1',
        data: {
          'payload':
              '{"type":"ORDER_SHIPPED","link":"orders/1042","delivery_id":"d1","params":{"order_id":1042}}',
          'extra': 'kept',
        },
      );
    final message = await FcmPushDriver(messaging: messaging).getInitialMessage();

    expect(message?.id, 'm1');
    expect(message?.type, 'ORDER_SHIPPED');
    expect(message?.payload.link, 'orders/1042');
    expect(message?.payload.deliveryId, 'd1');
    expect(message?.payload.params, {'order_id': 1042});
    expect(message?.data['extra'], 'kept');
  });

  test('flat type keys are no longer read', () async {
    final messaging = FakeFirebaseMessaging(AuthorizationStatus.authorized)
      ..initialMessage = const RemoteMessage(data: {'type': 'CHAT'});
    final message = await FcmPushDriver(messaging: messaging).getInitialMessage();

    expect(message?.type, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/index.dart';

import '../fake_hms_push_client.dart';

void main() {
  late FakeHmsPushClient client;
  late HmsPushDriver driver;

  setUp(() {
    client = FakeHmsPushClient();
    driver = HmsPushDriver(
      client: client,
      tokenTimeout: const Duration(milliseconds: 50),
    );
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('provider is hms', () {
    expect(driver.provider, PushProvider.hms);
  });

  group('message data', () {
    Future<PushMessage> foreground(HmsRawMessage raw) async {
      final next = driver.onForeground.first;
      client.dataController.add(raw);
      return next;
    }

    test('decodes valid JSON and reads type, id, title and body', () async {
      final message = await foreground(
        const HmsRawMessage(
          id: 'm1',
          rawData: '{"type":"ORDER_SHIPPED","order_id":"1042"}',
          title: 'Shipped',
          body: 'On its way',
        ),
      );

      expect(message.id, 'm1');
      expect(message.type, 'ORDER_SHIPPED');
      expect(message.title, 'Shipped');
      expect(message.body, 'On its way');
      expect(message.data, {'type': 'ORDER_SHIPPED', 'order_id': '1042'});
    });

    test('invalid JSON gives an empty map', () async {
      final message = await foreground(
        const HmsRawMessage(id: 'm2', rawData: '{oops'),
      );

      expect(message.data, isEmpty);
      expect(message.type, isNull);
    });

    test('non-object JSON gives an empty map', () async {
      final message = await foreground(
        const HmsRawMessage(rawData: '["a","b"]'),
      );

      expect(message.data, isEmpty);
    });

    test('null and empty data give an empty map', () async {
      expect((await foreground(const HmsRawMessage())).data, isEmpty);
      expect(
        (await foreground(const HmsRawMessage(rawData: ' '))).data,
        isEmpty,
      );
    });
  });

  group('token', () {
    test('returns the first non-empty token from the stream', () async {
      final result = driver.getToken();
      await settle();
      client.tokenController
        ..add('')
        ..add('hms-1');

      expect(await result, 'hms-1');
      expect(client.tokenRequests, 1);
    });

    test('returns null on timeout', () async {
      expect(await driver.getToken(), isNull);
      expect(client.tokenRequests, 1);
    });

    test('returns null when the stream errors', () async {
      final result = driver.getToken();
      await settle();
      client.tokenController.addError(StateError('boom'));

      expect(await result, isNull);
    });

    test('a token handed to getToken is not repeated as a refresh', () async {
      final refreshed = <String>[];
      final subscription = driver.onTokenRefresh.listen(refreshed.add);
      addTearDown(subscription.cancel);

      final result = driver.getToken();
      await settle();
      client.tokenController.add('hms-1');
      await result;
      client.tokenController.add('hms-1');
      await settle();

      expect(refreshed, isEmpty);
    });

    test('a changed token is emitted as a refresh', () async {
      final result = driver.getToken();
      await settle();
      client.tokenController.add('hms-1');
      await result;

      final next = driver.onTokenRefresh.first;
      client.tokenController.add('hms-2');

      expect(await next, 'hms-2');
    });

    test('deleteToken calls the client', () async {
      await driver.deleteToken();

      expect(client.deleteCount, 1);
    });
  });

  group('taps', () {
    test('onOpened maps extras and the data string', () async {
      final next = driver.onOpened.first;
      client.openedController.add(
        const HmsRawMessage(
          id: 'm3',
          rawData: '{"type":"CHAT","link":"app://chat/1"}',
          extras: {'type': 'stale', 'google.sent_time': 1},
        ),
      );
      final message = await next;

      expect(message.id, 'm3');
      expect(message.type, 'CHAT');
      expect(message.data['link'], 'app://chat/1');
    });

    test(
      'onOpened falls back to extras when no data string is present',
      () async {
        final next = driver.onOpened.first;
        client.openedController.add(
          const HmsRawMessage(extras: {'type': 'CHAT', 'link': 'app://chat/2'}),
        );
        final message = await next;

        expect(message.type, 'CHAT');
        expect(message.data['link'], 'app://chat/2');
      },
    );

    test('the data extra is decoded, not kept as a raw string', () async {
      final next = driver.onOpened.first;
      client.openedController.add(
        const HmsRawMessage(extras: {'data': '{"type":"CHAT"}'}),
      );
      final message = await next;

      expect(message.type, 'CHAT');
      expect(message.data.containsKey('data'), isFalse);
    });

    test('getInitialMessage maps the launching notification', () async {
      client.initial = const HmsRawMessage(
        id: 'm4',
        rawData: '{"type":"CHAT"}',
        title: 'Hi',
      );
      final message = await driver.getInitialMessage();

      expect(message?.id, 'm4');
      expect(message?.type, 'CHAT');
      expect(message?.title, 'Hi');
    });

    test(
      'getInitialMessage is null without a launching notification',
      () async {
        expect(await driver.getInitialMessage(), isNull);
      },
    );
  });

  group('permission', () {
    test('enabled notifications are authorized', () async {
      expect(await driver.getPermission(), PushPermission.authorized);
    });

    test('disabled notifications are denied', () async {
      client.notificationsEnabled = false;

      expect(await driver.getPermission(), PushPermission.denied);
    });

    test('requestPermission reports the granted result', () async {
      client
        ..notificationsEnabled = false
        ..grantOnRequest = true;

      expect(await driver.requestPermission(), PushPermission.authorized);
    });

    test('requestPermission reports a refusal as denied', () async {
      client
        ..notificationsEnabled = false
        ..grantOnRequest = false;

      expect(await driver.requestPermission(), PushPermission.denied);
    });
  });

  test('registers the background handler with the client', () async {
    void handler(dynamic message) {}
    HmsPushDriver(client: client, backgroundHandler: handler);
    await settle();

    expect(client.registeredBackgroundHandler, same(handler));
  });
}

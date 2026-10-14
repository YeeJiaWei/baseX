import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/push/default_hms_push_client.dart';

import 'fake_plugin_event_channel.dart';

void main() {
  late FakePluginEventChannel<String> tokens;
  late FakePluginEventChannel<dynamic> opened;
  late DefaultHmsPushClient client;

  setUp(() {
    tokens = FakePluginEventChannel<String>();
    opened = FakePluginEventChannel<dynamic>();
    client = DefaultHmsPushClient(
      tokenSource: () => tokens.stream,
      openedSource: () => opened.stream,
    );
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('token stream fan-out', () {
    test('subscribes to the plugin once however often it is read', () async {
      final subscriptions = [
        client.tokenStream.listen((_) {}),
        client.tokenStream.listen((_) {}),
        client.tokenStream.listen((_) {}),
      ];
      addTearDown(() => Future.wait(subscriptions.map((s) => s.cancel())));

      expect(tokens.listenCount, 1);
    });

    test('does not subscribe before the stream is first used', () {
      expect(tokens.listenCount, 0);
    });

    test('a cancelled listener does not silence the others', () async {
      final received = <String>[];
      final long = client.tokenStream.listen(received.add);
      addTearDown(long.cancel);

      final shortLived = client.tokenStream.listen((_) {});
      await shortLived.cancel();
      tokens.emit('rotated');
      await settle();

      expect(received, ['rotated']);
      expect(tokens.cancelCount, 0);
      expect(tokens.hasHandler, isTrue);
    });

    test('every listener receives each token', () async {
      final first = <String>[];
      final second = <String>[];
      final a = client.tokenStream.listen(first.add);
      final b = client.tokenStream.listen(second.add);
      addTearDown(() => Future.wait([a.cancel(), b.cancel()]));

      tokens.emit('t1');
      await settle();

      expect(first, ['t1']);
      expect(second, ['t1']);
    });

    test('plugin errors reach the listeners', () async {
      final errors = <Object>[];
      final subscription = client.tokenStream.listen(
        (_) {},
        onError: errors.add,
      );
      addTearDown(subscription.cancel);

      tokens.emitError(StateError('boom'));
      await settle();

      expect(errors, hasLength(1));
    });
  });

  group('notification opened', () {
    test('maps the real event shape', () async {
      final next = client.notificationOpened.first;
      opened.emit({
        'uriPage': 'app://chat/1',
        'remoteMessage': {
          'messageId': 'm1',
          'data': '{"type":"CHAT","link":"app://chat/1"}',
          'notification': {'title': 'Hi', 'body': 'There'},
        },
        'extras': {'type': 'CHAT', 'extra': 1},
      });
      final message = await next;

      expect(message.id, 'm1');
      expect(message.rawData, '{"type":"CHAT","link":"app://chat/1"}');
      expect(message.title, 'Hi');
      expect(message.body, 'There');
      expect(message.extras, {'type': 'CHAT', 'extra': 1});
    });

    test('tolerates a missing remoteMessage and extras', () async {
      final next = client.notificationOpened.first;
      opened.emit({'uriPage': 'app://x'});
      final message = await next;

      expect(message.id, isNull);
      expect(message.rawData, isNull);
      expect(message.extras, isEmpty);
    });

    test('subscribes to the plugin once for repeated reads', () async {
      final a = client.notificationOpened.listen((_) {});
      final b = client.notificationOpened.listen((_) {});
      addTearDown(() => Future.wait([a.cancel(), b.cancel()]));

      expect(opened.listenCount, 1);
    });
  });
}

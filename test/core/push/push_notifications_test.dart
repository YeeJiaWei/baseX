import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baseX/Core/index.dart';

import 'fake_push_driver.dart';
import 'fake_push_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePushDriver driver;
  late FakePushHandler handler;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    driver = FakePushDriver();
    handler = FakePushHandler();
  });

  tearDown(PushNotifications.reset);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<PushNotifications> bind() async {
    final push = await PushNotifications.bind(driver: driver, handler: handler);
    await settle();
    await settle();
    return push;
  }

  test('bind does not prompt and registers the fetched token', () async {
    final push = await bind();

    expect(driver.requestCount, 0);
    expect(push.token, 'token-1');
    expect(handler.registered, ['token-1']);
    expect(PushNotifications.maybeInstance, same(push));
  });

  test('bind returns without waiting for a slow token, then registers it',
      () async {
    driver.tokenCompleter = Completer<String?>();

    final push =
        await PushNotifications.bind(driver: driver, handler: handler);

    expect(push.token, isNull);
    expect(handler.registered, isEmpty);

    driver.tokenCompleter!.complete('late-token');
    await settle();
    await settle();

    expect(push.token, 'late-token');
    expect(handler.registered, ['late-token']);
  });

  test('a throwing permission read still wires listeners and fetches token',
      () async {
    driver.throwOnPermission = true;
    await bind();

    driver.foregroundController.add(const PushMessage(id: 'f1'));
    await settle();

    expect(handler.foreground, hasLength(1));
    expect(handler.registered, ['token-1']);
  });

  test('a throwing foreground presentation still wires listeners', () async {
    driver.throwOnPresentation = true;
    await bind();

    driver.foregroundController.add(const PushMessage(id: 'f1'));
    await settle();

    expect(handler.foreground, hasLength(1));
    expect(handler.registered, ['token-1']);
  });

  test('signIn triggers refreshRegistration', () async {
    await bind();
    final store = InMemoryAuthDriver();
    await XAuthStore.bind(store);
    handler.registered.clear();

    await store.signIn('bearer');
    await settle();

    expect(handler.registered, ['token-1']);
    XAuthStore.reset();
  });

  testWidgets('sign-out completes when unregisterToken never completes',
      (tester) async {
    final store = InMemoryAuthDriver();
    await tester.runAsync(() async {
      await bind();
      await XAuthStore.bind(store);
      await store.signIn('bearer');
    });
    handler.hangUnregister = true;

    var signedOut = false;
    unawaited(store.signOut().then((_) => signedOut = true));
    await tester.pump();
    expect(signedOut, isFalse);

    await tester.pump(PushNotifications.unregisterTimeout);
    await tester.pump();

    expect(signedOut, isTrue);
    expect(store.hasToken, isFalse);
    XAuthStore.reset();
  });

  test('bind survives a missing token', () async {
    driver.token = null;

    final push = await bind();

    expect(push.token, isNull);
    expect(handler.registered, isEmpty);
  });

  test('promptIfNeeded prompts once and sets the flag after it resolves',
      () async {
    final push = await bind();

    final first = await push.promptIfNeeded();
    final prefs = await SharedPreferences.getInstance();

    expect(first, PushPermission.authorized);
    expect(driver.requestCount, 1);
    expect(prefs.getBool(PushNotifications.promptShownKey), isTrue);
    expect(handler.registeredPermissions.last, PushPermission.authorized);

    driver.permission = PushPermission.denied;
    await push.promptIfNeeded();

    expect(driver.requestCount, 1);
  });

  test('promptIfNeeded leaves the flag unset when the prompt fails', () async {
    final push = await PushNotifications.bind(
        driver: _ThrowingDriver(), handler: handler);

    await push.promptIfNeeded();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getBool(PushNotifications.promptShownKey), isNull);
  });

  test('promptIfNeeded skips the prompt when already authorized', () async {
    driver.permission = PushPermission.authorized;
    final push = await bind();

    await push.promptIfNeeded();
    final prefs = await SharedPreferences.getInstance();

    expect(driver.requestCount, 0);
    expect(prefs.getBool(PushNotifications.promptShownKey), isTrue);
  });

  test('token refresh registers the new token then unregisters the previous',
      () async {
    await bind();

    driver.tokenController.add('token-2');
    await settle();

    expect(handler.registered, ['token-1', 'token-2']);
    expect(handler.unregistered, ['token-1']);
    expect(handler.unregisteredProviders, [PushProvider.fcm]);
  });

  test('registrations carry the driver provider', () async {
    driver.provider = PushProvider.hms;
    await bind();

    expect(handler.registrations.single.provider, PushProvider.hms);
  });

  test('a token persisted by the previous provider is unregistered after the switch',
      () async {
    SharedPreferences.setMockInitialValues(
        {PushNotifications.tokenKey: 'fcm-token'});
    driver
      ..provider = PushProvider.hms
      ..token = 'hms-token';

    await bind();

    expect(handler.registrations.single.token, 'hms-token');
    expect(handler.registrations.single.provider, PushProvider.hms);
    expect(handler.unregistered, ['fcm-token']);
  });

  test('a stored fcm token is never registered under hms and is unregistered',
      () async {
    SharedPreferences.setMockInitialValues({
      PushNotifications.tokenKey: 'fcm-token',
      PushNotifications.tokenProviderKey: 'fcm',
    });
    driver
      ..provider = PushProvider.hms
      ..tokenCompleter = Completer<String?>();
    final push = await PushNotifications.bind(driver: driver, handler: handler);

    final refresh = push.refreshRegistration();
    await settle();

    expect(handler.registered, isEmpty);
    expect(handler.unregistered, ['fcm-token']);
    expect(handler.unregisteredProviders, [PushProvider.fcm]);

    driver.tokenCompleter!.complete('hms-token');
    await refresh;
    await settle();

    final prefs = await SharedPreferences.getInstance();
    expect(handler.registered.toSet(), {'hms-token'});
    expect(handler.registrations.map((r) => r.provider).toSet(),
        {PushProvider.hms});
    expect(handler.unregistered, ['fcm-token']);
    expect(prefs.getString(PushNotifications.tokenProviderKey), 'hms');
  });

  test('a stored token with no provider is treated as fcm', () async {
    SharedPreferences.setMockInitialValues(
        {PushNotifications.tokenKey: 'legacy-token'});
    driver
      ..provider = PushProvider.hms
      ..tokenCompleter = Completer<String?>();
    final push = await PushNotifications.bind(driver: driver, handler: handler);

    unawaited(push.refreshRegistration());
    await settle();

    expect(handler.registered, isEmpty);
    expect(handler.unregistered, ['legacy-token']);
    expect(handler.unregisteredProviders, [PushProvider.fcm]);
  });

  test('a legacy token is kept when the driver is fcm', () async {
    SharedPreferences.setMockInitialValues(
        {PushNotifications.tokenKey: 'token-1'});
    await bind();

    expect(handler.unregistered, isEmpty);
    expect(handler.registered, ['token-1']);
  });

  test('sign-out unregisters a stale token under its own provider', () async {
    SharedPreferences.setMockInitialValues({
      PushNotifications.tokenKey: 'fcm-token',
      PushNotifications.tokenProviderKey: 'fcm',
    });
    driver
      ..provider = PushProvider.hms
      ..tokenCompleter = Completer<String?>();
    final push = await PushNotifications.bind(driver: driver, handler: handler);

    await push.unregisterCurrentToken();

    expect(handler.unregistered, ['fcm-token']);
    expect(handler.unregisteredProviders, [PushProvider.fcm]);
  });

  test('a repeat of the same token does not unregister', () async {
    await bind();

    driver.tokenController.add('token-1');
    await settle();

    expect(handler.unregistered, isEmpty);
  });

  test('dedup drops a repeat tap with the same key', () async {
    driver.initialMessage = const PushMessage(id: 'm1', payload: PushPayload(type: 'chat'));
    await bind();

    driver.openedController.add(const PushMessage(id: 'm1', payload: PushPayload(type: 'chat')));
    await settle();

    expect(handler.opened, hasLength(1));
    expect(handler.receipts, [PushReceipt.opened]);
  });

  test('a different key is handled', () async {
    driver.initialMessage = const PushMessage(id: 'm1');
    await bind();

    driver.openedController.add(const PushMessage(id: 'm2'));
    await settle();

    expect(handler.opened, hasLength(2));
  });

  test('foreground message reports received and calls onForeground', () async {
    await bind();

    driver.foregroundController.add(const PushMessage(id: 'f1', payload: PushPayload(type: 'chat')));
    await settle();

    expect(handler.receipts, [PushReceipt.received]);
    expect(handler.foreground, hasLength(1));
  });

  test('lastMessageType fires again on a repeated type', () async {
    final push = await bind();
    final seen = <String?>[];
    push.lastMessageType.listen(seen.add);

    driver.foregroundController.add(const PushMessage(id: 'a', payload: PushPayload(type: 'chat')));
    await settle();
    driver.foregroundController.add(const PushMessage(id: 'b', payload: PushPayload(type: 'chat')));
    await settle();

    expect(seen, [null, 'chat', null, 'chat']);
  });

  test('resume with a changed permission re-registers', () async {
    final push = await bind();
    expect(handler.registered, hasLength(1));

    driver.permission = PushPermission.authorized;
    await push.onResumed();

    expect(push.isAuthorized, isTrue);
    expect(handler.registered, hasLength(2));
    expect(handler.registeredPermissions.last, PushPermission.authorized);
  });

  test('resume with an unchanged permission does nothing', () async {
    final push = await bind();

    await push.onResumed();

    expect(handler.registered, hasLength(1));
  });

  test('registration failure does not throw', () async {
    handler.failRegistration = true;

    final push = await bind();

    await expectLater(push.refreshRegistration(), completes);
  });

  test('sign-out unregisters the token before it is cleared', () async {
    await bind();
    final store = InMemoryAuthDriver();
    await XAuthStore.bind(store);
    await store.signIn('bearer');
    var unregisteredBeforeClear = false;

    await store.signOut(remote: () async {
      unregisteredBeforeClear =
          handler.unregistered.contains('token-1') && store.hasToken;
    });

    expect(unregisteredBeforeClear, isTrue);
    expect(store.hasToken, isFalse);
    XAuthStore.reset();
  });
}

class _ThrowingDriver extends FakePushDriver {
  @override
  Future<PushPermission> requestPermission() async => throw StateError('boom');
}

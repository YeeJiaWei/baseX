import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/index.dart';

class _TestConfig extends NotificationLinkConfig {
  _TestConfig({
    required this.routes,
    this.events = const [],
    this.guards = const [],
  });

  @override
  String get scheme => 'shop';
  @override
  final List<LinkHandler> routes;
  @override
  final List<EventHandler> events;
  @override
  final List<LinkGuard> guards;

  final unknown = <Uri>[];
  final errors = <Object>[];

  @override
  void onUnknown(Uri uri) => unknown.add(uri);

  @override
  void onError(Uri uri, Object error, StackTrace stackTrace) =>
      errors.add(error);
}

class _FixedGuard extends LinkGuard {
  _FixedGuard(this.result, this.calls);

  final GuardResult result;
  final List<String> calls;

  @override
  Future<GuardResult> check(LinkMatch link) async {
    calls.add('guard');
    return result;
  }
}

class _ThrowingGuard extends LinkGuard {
  @override
  Future<GuardResult> check(LinkMatch link) async =>
      throw StateError('guard boom');
}

class _VetoRoute extends LinkHandler {
  _VetoRoute(this.calls);

  final List<String> calls;

  @override
  String get pattern => 'chat/{conversationId}';

  @override
  Future<bool> canHandle(LinkMatch link) async => false;

  @override
  Future<void> handle(LinkMatch link) async => calls.add('veto-handled');
}

class _OrderEvent extends EventHandler {
  _OrderEvent(this.received);

  final List<LinkMatch> received;

  @override
  Set<String> get types => {'ORDER_SHIPPED'};
  @override
  Map<String, LinkParam> get require => {'order_id': LinkParam.int};
  @override
  Map<String, List<String>> get aliases => {
        'order_id': ['orderId']
      };

  @override
  Future<void> handle(LinkMatch event) async => received.add(event);
}

void main() {
  late List<String> calls;

  LinkRoute record(String pattern,
      {List<LinkGuard> guards = const [], bool public = false}) {
    return LinkRoute(
      pattern,
      (link) async => calls.add('$pattern ${link.uri.path}'),
      guards: guards,
      public: public,
    );
  }

  NotificationLinks bindRoutes(_TestConfig config) {
    NotificationLinks.bind(config);
    return NotificationLinks.instance;
  }

  setUp(() => calls = []);

  group('bind', () {
    test('instance returns the bound router', () {
      NotificationLinks.bind(_TestConfig(routes: const []));

      expect(NotificationLinks.instance, same(NotificationLinks.maybeInstance));
    });

    test('two routes tying on every segment throw', () {
      expect(
        () => NotificationLinks.bind(_TestConfig(routes: [
          record('orders/{id:int}'),
          record('orders/{number:int}'),
        ])),
        throwsArgumentError,
      );
    });

    test('literal routes and constrained routes coexist', () {
      expect(
        () => NotificationLinks.bind(_TestConfig(routes: [
          record('orders/history'),
          record('orders/{id:int}'),
          record('chat/**'),
        ])),
        returnsNormally,
      );
    });
  });

  group('routing', () {
    test('literal beats {id:int} regardless of list order', () async {
      final links = bindRoutes(_TestConfig(routes: [
        record('orders/{id:int}'),
        record('orders/history'),
      ]));

      expect(await links.handle('shop://orders/history'), isTrue);
      expect(await links.handle('shop://orders/42'), isTrue);
      expect(calls, ['orders/history /history', 'orders/{id:int} /42']);
    });

    test('{id:int} non-number falls through to the plain param route',
        () async {
      final links = bindRoutes(_TestConfig(routes: [
        record('orders/{id:int}'),
        record('orders/{reference}'),
      ]));

      await links.handle('shop://orders/abc');

      expect(calls, ['orders/{reference} /abc']);
    });

    test('optional segment shares a route with its parent', () async {
      final links = bindRoutes(_TestConfig(routes: [
        record('settings/notifications'),
        record('settings/{section?}'),
      ]));

      await links.handle('shop://settings');
      await links.handle('shop://settings/privacy');
      await links.handle('shop://settings/notifications');

      expect(calls, [
        'settings/{section?} ',
        'settings/{section?} /privacy',
        'settings/notifications /notifications',
      ]);
    });

    test('double star matches zero segments', () async {
      final links = bindRoutes(_TestConfig(routes: [record('help/**')]));

      expect(await links.handle('shop://help'), isTrue);
      expect(await links.handle('shop://help/faq/123/'), isTrue);
      expect(calls, hasLength(2));
    });

    test('root pattern matches an empty link', () async {
      final links = bindRoutes(_TestConfig(routes: [record('/')]));

      expect(await links.handle('shop://'), isTrue);
    });

    test('match exposes params, query and source', () async {
      late LinkMatch seen;
      final links = bindRoutes(_TestConfig(routes: [
        LinkRoute('orders/{id:int}', (link) async => seen = link),
      ]));

      await links.handle('shop://orders/7?tab=2', source: LinkSource.push);

      expect(seen.int('id'), 7);
      expect(seen.query, {'tab': '2'});
      expect(seen.source, LinkSource.push);
      expect(seen.data, isEmpty);
    });

    test('wrong scheme goes to onUnknown and never navigates', () async {
      final config = _TestConfig(routes: [record('help/**')]);
      final links = bindRoutes(config);

      expect(await links.handle('https://help/faq'), isFalse);
      expect(await links.handle('other://help'), isFalse);
      expect(calls, isEmpty);
      expect(config.unknown, hasLength(2));
    });

    test('no match and null link go to onUnknown', () async {
      final config = _TestConfig(routes: [record('orders')]);
      final links = bindRoutes(config);

      expect(await links.handle('shop://nothing'), isFalse);
      expect(await links.handle(null), isFalse);
      expect(config.unknown, hasLength(2));
    });
  });

  group('guards', () {
    test('allow continues to the handler', () async {
      final links = bindRoutes(_TestConfig(routes: [
        record('a', guards: [_FixedGuard(const GuardResult.allow(), calls)]),
      ]));

      expect(await links.handle('shop://a'), isTrue);
      expect(calls, ['guard', 'a ']);
    });

    test('skip tries the next matching route', () async {
      final links = bindRoutes(_TestConfig(routes: [
        record('orders/{id:int}',
            guards: [_FixedGuard(const GuardResult.skip(), calls)]),
        record('orders/{reference}'),
      ]));

      expect(await links.handle('shop://orders/5'), isTrue);
      expect(calls, ['guard', 'orders/{reference} /5']);
    });

    test('stop ends dispatch and reports handled', () async {
      final links = bindRoutes(_TestConfig(routes: [
        record('orders/{id:int}',
            guards: [_FixedGuard(const GuardResult.stop(), calls)]),
        record('orders/{reference}'),
      ]));

      expect(await links.handle('shop://orders/5'), isTrue);
      expect(calls, ['guard']);
    });

    test('config guards run before route guards and public skips them',
        () async {
      final links = bindRoutes(_TestConfig(
        guards: [_FixedGuard(const GuardResult.stop(), calls)],
        routes: [
          record('private'),
          record('open', public: true),
        ],
      ));

      await links.handle('shop://private');
      expect(calls, ['guard']);

      calls.clear();
      await links.handle('shop://open');
      expect(calls, ['open ']);
    });

    test('canHandle false falls through to the next route', () async {
      final links = bindRoutes(_TestConfig(routes: [
        _VetoRoute(calls),
        record('chat/**'),
      ]));

      expect(await links.handle('shop://chat/9'), isTrue);
      expect(calls, ['chat/** /9']);
    });
  });

  group('errors', () {
    test('handler throw goes to onError, returns false, no other route runs',
        () async {
      final config = _TestConfig(routes: [
        LinkRoute('orders/{id:int}', (_) async => throw StateError('boom')),
        record('orders/{reference}'),
      ]);
      final links = bindRoutes(config);

      expect(await links.handle('shop://orders/5'), isFalse);
      expect(config.errors.single, isA<StateError>());
      expect(calls, isEmpty);
    });

    test('guard throw goes to onError', () async {
      final config = _TestConfig(routes: [
        record('a', guards: [_ThrowingGuard()])
      ]);
      final links = bindRoutes(config);

      expect(await links.handle('shop://a'), isFalse);
      expect(config.errors.single, isA<StateError>());
    });
  });

  group('events', () {
    test('require passes string ints and carries data', () async {
      final received = <LinkMatch>[];
      final links = bindRoutes(_TestConfig(
        routes: const [],
        events: [_OrderEvent(received)],
      ));

      final handled =
          await links.handleEvent('ORDER_SHIPPED', {'order_id': '1042'});

      expect(handled, isTrue);
      expect(received.single.int('order_id'), 1042);
      expect(received.single.data['order_id'], '1042');
      expect(received.single.source, LinkSource.push);
    });

    test('aliases supply older key names', () async {
      final received = <LinkMatch>[];
      final links = bindRoutes(_TestConfig(
        routes: const [],
        events: [_OrderEvent(received)],
      ));

      await links.handleEvent('ORDER_SHIPPED', {'orderId': 8});

      expect(received.single.int('order_id'), 8);
    });

    test('missing or invalid required field skips the handler', () async {
      final received = <LinkMatch>[];
      final config =
          _TestConfig(routes: const [], events: [_OrderEvent(received)]);
      final links = bindRoutes(config);

      expect(await links.handleEvent('ORDER_SHIPPED', {'order_id': 'abc'}),
          isFalse);
      expect(await links.handleEvent('ORDER_SHIPPED', {}), isFalse);
      expect(received, isEmpty);
      expect(config.unknown, hasLength(2));
    });

    test('unmatched event falls back to the link key with data carried',
        () async {
      late LinkMatch seen;
      final links = bindRoutes(_TestConfig(
        routes: [LinkRoute('orders/{id:int}', (link) async => seen = link)],
      ));

      final handled = await links.handleEvent(
        'SOMETHING_ELSE',
        {'link': 'shop://orders/3', 'extra': 'x'},
      );

      expect(handled, isTrue);
      expect(seen.int('id'), 3);
      expect(seen.data['extra'], 'x');
      expect(seen.source, LinkSource.push);
    });

    test('closure event route with guards and a custom link key', () async {
      final links = bindRoutes(_TestConfig(
        routes: const [],
        events: [
          EventRoute(
            types: {'PLAN_EXPIRED'},
            action: (_) async => calls.add('expired'),
            guards: [_FixedGuard(const GuardResult.allow(), calls)],
          ),
        ],
      ));

      expect(await links.handleEvent('PLAN_EXPIRED', {}), isTrue);
      expect(calls, ['guard', 'expired']);
    });

    test('event handler throw goes to onError', () async {
      final config = _TestConfig(
        routes: const [],
        events: [
          EventRoute(
              types: {'X'}, action: (_) async => throw StateError('boom'))
        ],
      );
      final links = bindRoutes(config);

      expect(await links.handleEvent('X', {}), isFalse);
      expect(config.errors, hasLength(1));
    });
  });

  group('hold', () {
    test('queues only the latest call and release runs it', () async {
      final links = bindRoutes(_TestConfig(routes: [record('a'), record('b')]));

      links.hold();
      expect(await links.handle('shop://a'), isFalse);
      expect(await links.handle('shop://b'), isFalse);
      expect(calls, isEmpty);

      await links.release();
      expect(calls, ['b ']);

      expect(await links.handle('shop://a'), isTrue);
    });

    test('held events are queued too', () async {
      final links = bindRoutes(_TestConfig(
        routes: const [],
        events: [
          EventRoute(types: {'X'}, action: (_) async => calls.add('x'))
        ],
      ));

      links.hold();
      expect(await links.handleEvent('X', {}), isFalse);
      await links.release();

      expect(calls, ['x']);
    });

    test('discard drops the queued link and ends the hold', () async {
      final links = bindRoutes(_TestConfig(routes: [record('a')]));

      links.hold();
      await links.handle('shop://a');
      links.discard();
      await links.release();

      expect(calls, isEmpty);
      expect(await links.handle('shop://a'), isTrue);
    });

    test('holdLink queues one link without a global hold', () async {
      final links = bindRoutes(_TestConfig(routes: [record('a'), record('b')]));

      links.holdLink(Uri.parse('shop://a'));
      expect(await links.handle('shop://b'), isTrue);
      expect(calls, ['b ']);

      await links.release();
      expect(calls, ['b ', 'a ']);
    });

    test('release with nothing queued does nothing', () async {
      final links = bindRoutes(_TestConfig(routes: [record('a')]));

      await links.release();

      expect(calls, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/index.dart';

class _TestConfig extends NotificationLinkConfig {
  _TestConfig({
    required this.routes,
    this.events = const [],
    this.guards = const [],
    this.scheme = 'shop',
  });

  @override
  final String? scheme;
  @override
  final List<LinkHandler> routes;
  @override
  final List<EventHandler> events;
  @override
  final List<LinkGuard> guards;

  final unknown = <Uri>[];
  final errors = <Object>[];
  bool throwOnUnknown = false;

  @override
  void onUnknown(Uri uri) {
    unknown.add(uri);
    if (throwOnUnknown) throw StateError('unknown boom');
  }

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
      expect(seen.eventParams, isEmpty);
    });

    test('wrong scheme goes to onUnknown and never navigates', () async {
      final config = _TestConfig(routes: [record('help/**')]);
      final links = bindRoutes(config);

      expect(await links.handle('https://help/faq'), isFalse);
      expect(await links.handle('other://help'), isFalse);
      expect(calls, isEmpty);
      expect(config.unknown, hasLength(2));
    });

    test('plain paths route, with or without a leading slash', () async {
      final links = bindRoutes(_TestConfig(routes: [record('orders/{id:int}')]));

      expect(await links.handle('orders/7'), isTrue);
      expect(await links.handle('/orders/8?tab=1'), isTrue);
      expect(calls, hasLength(2));
    });

    test('without a scheme any scheme link goes to onUnknown', () async {
      final config = _TestConfig(routes: [record('help/**')], scheme: null);
      final links = bindRoutes(config);

      expect(await links.handle('shop://help/faq'), isFalse);
      expect(await links.handle('help/faq'), isTrue);
      expect(config.unknown, hasLength(1));
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
    test('a throwing onUnknown goes to onError and returns false', () async {
      final config = _TestConfig(routes: const [])..throwOnUnknown = true;
      final links = bindRoutes(config);

      expect(await links.handleEvent('NOPE'), isFalse);
      expect(await links.handle('shop://missing'), isFalse);
      expect(config.errors, hasLength(2));
      expect(config.errors.first, isA<StateError>());
    });

    test('an empty link falls back to the event uri', () async {
      final received = <LinkMatch>[];
      final links = bindRoutes(_TestConfig(
        routes: const [],
        events: [_OrderEvent(received)],
      ));

      await links.handleEvent(
        'ORDER_SHIPPED',
        params: {'order_id': '1'},
        link: '  ',
      );

      expect(received.single.uri, Uri.parse('event/ORDER_SHIPPED'));
    });

    test('require passes numeric strings and carries params', () async {
      final received = <LinkMatch>[];
      final links = bindRoutes(_TestConfig(
        routes: const [],
        events: [_OrderEvent(received)],
      ));

      final handled =
          await links.handleEvent('ORDER_SHIPPED', params: {'order_id': '1042'});

      expect(handled, isTrue);
      expect(received.single.int('order_id'), 1042);
      expect(received.single.eventParams['order_id'], '1042');
      expect(received.single.eventType, 'ORDER_SHIPPED');
      expect(received.single.source, LinkSource.push);
    });

    test('require accepts real ints from JSON', () async {
      final received = <LinkMatch>[];
      final links = bindRoutes(_TestConfig(
        routes: const [],
        events: [_OrderEvent(received)],
      ));

      expect(
        await links.handleEvent('ORDER_SHIPPED', params: {'order_id': 1042}),
        isTrue,
      );
      expect(received.single.int('order_id'), 1042);
      expect(received.single.eventParams['order_id'], 1042);
    });

    test('a plain-path link falls back after an event miss', () async {
      late LinkMatch seen;
      final links = bindRoutes(_TestConfig(
        routes: [LinkRoute('orders/{id:int}', (link) async => seen = link)],
      ));

      expect(await links.handleEvent('X', link: 'orders/9'), isTrue);
      expect(seen.int('id'), 9);
    });

    test('aliases supply older key names', () async {
      final received = <LinkMatch>[];
      final links = bindRoutes(_TestConfig(
        routes: const [],
        events: [_OrderEvent(received)],
      ));

      await links.handleEvent('ORDER_SHIPPED', params: {'orderId': 8});

      expect(received.single.int('order_id'), 8);
    });

    test('missing or invalid required field skips the handler', () async {
      final received = <LinkMatch>[];
      final config =
          _TestConfig(routes: const [], events: [_OrderEvent(received)]);
      final links = bindRoutes(config);

      expect(await links.handleEvent('ORDER_SHIPPED', params: {'order_id': 'abc'}),
          isFalse);
      expect(await links.handleEvent('ORDER_SHIPPED'), isFalse);
      expect(received, isEmpty);
      expect(config.unknown, hasLength(2));
    });

    test('unmatched event falls back to the link with params carried',
        () async {
      late LinkMatch seen;
      final links = bindRoutes(_TestConfig(
        routes: [LinkRoute('orders/{id:int}', (link) async => seen = link)],
      ));

      final handled = await links.handleEvent(
        'SOMETHING_ELSE',
        params: {'extra': 'x'},
        link: 'shop://orders/3',
      );

      expect(handled, isTrue);
      expect(seen.int('id'), 3);
      expect(seen.eventParams['extra'], 'x');
      expect(seen.source, LinkSource.push);
    });

    test('closure event route with guards ', () async {
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

      expect(await links.handleEvent('PLAN_EXPIRED'), isTrue);
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

      expect(await links.handleEvent('X'), isFalse);
      expect(config.errors, hasLength(1));
    });
  });

  group('plain path detection', () {
    test('a plain path with :// only in its query stays a plain path', () async {
      final links = bindRoutes(_TestConfig(routes: [record('orders/{id:int}')]));

      expect(await links.handle('orders/1?next=https://x'), isTrue);
      expect(calls, ['orders/{id:int} /orders/1']);
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
      expect(await links.handleEvent('X'), isFalse);
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

      links.holdLink(LinkMatch(uri: Uri.parse('shop://a'), source: LinkSource.push));
      expect(await links.handle('shop://b'), isTrue);
      expect(calls, ['b ']);

      await links.release();
      expect(calls, ['b ', 'a ']);
    });

    test('holdLink replays with the original source and event params', () async {
      final received = <LinkMatch>[];
      final links = bindRoutes(_TestConfig(routes: [
        LinkRoute('a', (link) async => received.add(link)),
      ]));

      links.holdLink(LinkMatch(
        uri: Uri.parse('shop://a'),
        source: LinkSource.push,
        eventParams: const {'order_id': '7'},
      ));
      await links.release();

      expect(received.single.source, LinkSource.push);
      expect(received.single.eventParams, {'order_id': '7'});
    });

    test('a held event match with a link re-runs the event route on release',
        () async {
      final received = <LinkMatch>[];
      final links = bindRoutes(_TestConfig(
        routes: [record('orders/{id:int}')],
        events: [_OrderEvent(received)],
      ));

      links.holdLink(LinkMatch(
        uri: Uri.parse('/orders/3'),
        source: LinkSource.push,
        eventParams: const {'order_id': 9},
        eventType: 'ORDER_SHIPPED',
      ));
      await links.release();

      expect(received.single.eventType, 'ORDER_SHIPPED');
      expect(received.single.source, LinkSource.push);
      expect(received.single.int('order_id'), 9);
      expect(calls, isEmpty);
    });

    test('a held event match without a link re-runs the event route on release',
        () async {
      final received = <LinkMatch>[];
      final config = _TestConfig(
        routes: const [],
        events: [_OrderEvent(received)],
      );
      final links = bindRoutes(config);

      links.holdLink(LinkMatch(
        uri: Uri(path: 'event/ORDER_SHIPPED'),
        source: LinkSource.push,
        eventParams: const {'order_id': 9},
        eventType: 'ORDER_SHIPPED',
      ));
      await links.release();

      expect(received.single.eventType, 'ORDER_SHIPPED');
      expect(config.unknown, isEmpty);
    });

    test('release with nothing queued does nothing', () async {
      final links = bindRoutes(_TestConfig(routes: [record('a')]));

      await links.release();

      expect(calls, isEmpty);
    });
  });
}

import 'package:baseX/Core/index.dart';
import 'package:flutter_test/flutter_test.dart';

class _RoutingOnlyPushHandler extends PushHandler {
  @override
  Future<void> registerToken(PushRegistration registration) async {}

  @override
  Future<void> unregisterToken(String token, PushProvider provider) async {}
}

class _ShopLinks extends NotificationLinkConfig {
  _ShopLinks(this.routedOrderIds, this.routedPaths);

  final List<int> routedOrderIds;
  final List<String> routedPaths;

  @override
  String get scheme => 'shop';

  @override
  List<LinkHandler> get routes => [
        LinkRoute('help/**', (link) async => routedPaths.add(link.uri.toString())),
      ];

  @override
  List<EventHandler> get events => [
        EventRoute(
          types: {'ORDER_SHIPPED'},
          require: {'order_id': LinkParam.int},
          action: (event) async => routedOrderIds.add(event.int('order_id')),
        ),
      ];
}

void main() {
  test('default onOpened routes the push type through NotificationLinks', () async {
    final routedOrderIds = <int>[];
    NotificationLinks.bind(_ShopLinks(routedOrderIds, []));

    _RoutingOnlyPushHandler().onOpened(
      const PushMessage(type: 'ORDER_SHIPPED', data: {'type': 'ORDER_SHIPPED', 'order_id': '1042'}),
    );
    await pumpEventQueue();

    expect(routedOrderIds, [1042]);
  });

  test('default onOpened falls back to the payload link when no event route matches', () async {
    final routedPaths = <String>[];
    NotificationLinks.bind(_ShopLinks([], routedPaths));

    _RoutingOnlyPushHandler().onOpened(
      const PushMessage(type: 'HELP_REPLY', data: {'type': 'HELP_REPLY', 'link': 'shop://help/faq'}),
    );
    await pumpEventQueue();

    expect(routedPaths, ['shop://help/faq']);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/Core/index.dart';

void main() {
  const fields = {
    'type': 'ORDER_SHIPPED',
    'link': 'orders/1042',
    'delivery_id': '0190a3b2',
    'params': {'order_id': 1042, 'express': true},
  };

  void expectFull(PushPayload payload) {
    expect(payload.type, 'ORDER_SHIPPED');
    expect(payload.link, 'orders/1042');
    expect(payload.deliveryId, '0190a3b2');
    expect(payload.params, {'order_id': 1042, 'express': true});
  }

  test('parses a JSON string value', () {
    expectFull(PushPayload.fromData({'payload': jsonEncode(fields)}));
  });

  test('parses a map value as Huawei delivers it', () {
    expectFull(PushPayload.fromData({'payload': fields}));
  });

  test('ignores other data keys', () {
    final payload = PushPayload.fromData({
      'payload': jsonEncode({'type': 'A'}),
      'type': 'B',
      'link': 'x',
    });

    expect(payload.type, 'A');
    expect(payload.link, isNull);
  });

  test('missing payload gives an empty payload', () {
    final payload = PushPayload.fromData({'other': '1'});

    expect(payload.type, isNull);
    expect(payload.params, isEmpty);
  });

  test('malformed JSON gives an empty payload without throwing', () {
    final payload = PushPayload.fromData({'payload': '{oops'});

    expect(payload.type, isNull);
    expect(payload.params, isEmpty);
  });

  test('non-object payload gives an empty payload', () {
    expect(PushPayload.fromData({'payload': '["a"]'}).type, isNull);
    expect(PushPayload.fromData({'payload': 5}).type, isNull);
  });

  test('wrong field types are dropped, the rest is kept', () {
    final payload = PushPayload.fromData({
      'payload': jsonEncode({
        'type': 7,
        'link': 'orders/1',
        'delivery_id': ['x'],
        'params': 'nope',
      }),
    });

    expect(payload.type, isNull);
    expect(payload.link, 'orders/1');
    expect(payload.deliveryId, isNull);
    expect(payload.params, isEmpty);
  });

  test('blank strings count as absent', () {
    final payload = PushPayload.fromData({
      'payload': jsonEncode({'type': ' ', 'link': ''}),
    });

    expect(payload.type, isNull);
    expect(payload.link, isNull);
  });
}

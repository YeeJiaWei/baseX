import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baseX/api_service/interceptor/device_header_interceptor.dart';
import 'package:baseX/Core/index.dart';

class _Capture extends RequestInterceptorHandler {
  RequestOptions? captured;

  @override
  void next(RequestOptions requestOptions) => captured = requestOptions;
}

Map<String, dynamic> _headers() {
  final handler = _Capture();
  DeviceHeaderInterceptor().onRequest(RequestOptions(path: '/x'), handler);
  return handler.captured!.headers;
}

void main() {
  setUp(() {
    baseConstant = BaseConstant();
  });

  tearDown(() {
    DeviceInfo.instance.debugSet();
    AppInfo.instance.debugSet();
  });

  test('headers carry the device and app values', () {
    DeviceInfo.instance.debugSet(osVersion: '17.4', model: 'iPhone 15', id: 'abc-123');
    AppInfo.instance.debugSet(version: '2.3.4');

    final headers = _headers();

    expect(headers['App-Version'], '2.3.4');
    expect(headers['Device-Model'], 'iPhone 15');
    expect(headers['Device-ID'], 'abc-123');
    expect(headers['Os-Version'], '17.4');
    expect(headers['Os-Type'], DeviceInfo.instance.os);
  });

  test('Device-ID and Os-Version are omitted when empty', () {
    DeviceInfo.instance.debugSet(model: 'Pixel');
    AppInfo.instance.debugSet(version: '1.0.0');

    final headers = _headers();

    expect(headers.containsKey('Device-ID'), isFalse);
    expect(headers.containsKey('Os-Version'), isFalse);
    expect(headers['Device-Model'], 'Pixel');
  });
}

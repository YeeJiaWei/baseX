import 'package:dio/dio.dart';

import 'package:baseX/Core/index.dart';

import 'package:baseX/api_service/support/interceptor_mixin.dart';

import 'package:baseX/api_service/client/api_x_service.dart';

class XLoggerInterceptors extends Interceptor with InterceptorMixin {
  /// Request on error will throw custom Exception Error
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final opt = err.requestOptions;
    final status = err.response != null
        ? '${err.response?.statusCode} ${err.response?.statusMessage ?? ''}'
            .trim()
        : err.type.name;

    XLogger.httpLine(
      failed: true,
      title: '${opt.method.toUpperCase()} ${opt.uri} → $status',
    );

    return handler.next(err);
  }

  /// Request on response
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final opt = response.requestOptions;

    // baseX treats a 2xx envelope with status != true as a logical failure.
    final data = response.data;
    bool failed = false;
    if (data is Map && data.containsKey('code') && baseConstant.success200) {
      if (data['code'] >= 200 && data['status'] != true) failed = true;
    }

    XLogger.httpLine(
      failed: failed,
      title: '${opt.method.toUpperCase()} ${opt.uri} → ${response.statusCode}',
    );

    return handler.next(response);
  }
}

/// Trait: appends [XLoggerInterceptors] to the connection's stack. Declare it
/// last so every earlier trait's headers/mutations show up in the logs.
mixin XLoggerApiMixin on ApiXService {
  @override
  List<Interceptor> get interceptors =>
      [...super.interceptors, XLoggerInterceptors()];
}

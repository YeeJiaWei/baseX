import 'package:dio/dio.dart';

import 'package:baseX/Core/index.dart';

import 'package:baseX/api_service/support/interceptor_mixin.dart';

import 'package:baseX/api_service/client/api_x_service.dart';

class XLoggerInterceptors extends Interceptor with InterceptorMixin {
  /// Buffers each request's log lines until its response/error arrives, so the
  /// whole exchange prints as one block (one icon) keyed by request identity.
  static final Map<int, List<String>> _pending = {};

  /// Request on header
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Buffer the request — it prints later as part of the response/error block.
    final method = options.method.toUpperCase();
    final lines = <String>['→ ${options.baseUrl}${options.path}'];
    if (method == 'GET' && options.queryParameters.isNotEmpty) {
      lines.add('→ query: ${options.queryParameters}');
    }
    if (options.data != null) {
      try {
        final bodyMap =
            Map<String, dynamic>.fromEntries(options.data.fields);
        if (bodyMap.isNotEmpty) lines.add('→ body: $bodyMap');
      } catch (_) {
        lines.add('→ body: ${options.data}');
      }
    }
    _pending[options.hashCode] = lines;

    return handler.next(options);
  }

  /// Request on error will throw custom Exception Error
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final opt = err.requestOptions;
    final lines = _pending.remove(opt.hashCode) ?? <String>[];

    final status = err.response != null
        ? '${err.response?.statusCode} ${err.response?.statusMessage ?? ''}'
            .trim()
        : err.type.name;
    if (err.response?.data != null) {
      lines.add('← ${err.response?.data}');
    } else if (err.message != null) {
      lines.add('← ${err.message}');
    }

    XLogger.httpBlock(
      failed: true,
      title: '${opt.method.toUpperCase()} ${opt.path} → $status',
      lines: lines,
    );

    return handler.next(err);
  }

  /// Request on response
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final opt = response.requestOptions;
    final lines = _pending.remove(opt.hashCode) ?? <String>[];

    // baseX treats a 2xx envelope with status != true as a logical failure.
    final data = response.data;
    bool failed = false;
    if (data is Map && data.containsKey('code') && baseConstant.success200) {
      if (data['code'] >= 200 && data['status'] != true) failed = true;
    }

    lines.add('← $data');

    XLogger.httpBlock(
      failed: failed,
      title: '${opt.method.toUpperCase()} ${opt.path} → ${response.statusCode}',
      lines: lines,
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

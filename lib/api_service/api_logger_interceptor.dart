part of 'index.dart';

class XLoggerInterceptors extends Interceptor with InterceptorMixin {
  /// Buffers each request's log lines until its response/error arrives, so the
  /// whole exchange prints as one block (one icon) keyed by request identity.
  static final Map<int, List<String>> _pending = {};

  /// Request on header
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    Map<String, String?> header = {
      Headers.acceptHeader: Headers.jsonContentType,
      'App-Version': baseConstant.appVersion.value,
      'Os-Type': GetPlatform.isIOS ? 'ios' : 'android',
      if (defaultLangController != null)
        'Label-Version': defaultLangController?.labelVersion,
      if (Get.locale != null) 'Accept-Language': Get.locale?.languageCode,
      'Device-Model': baseConstant.deviceModel.value,
      if (baseConstant.deviceId.value != '')
        'Device-ID': baseConstant.deviceId.value,
      if (baseConstant.osVersion.value != '')
        'Os-Version': baseConstant.osVersion.value,
      // 'Device-Type': Platform.isIOS ? 'ios' : 'android',
      // 'Version-Type': baseConstant.versionType,
      // 'API-Version': baseConstant.api_version,
    };

    header.addAll(baseConstant.additionalHeader);

    if (options.headers.containsKey('headerType')) {
      if (options.headers['headerType'] == HeaderType.authorized && X != null) {
        options.headers.addAll(
            {HttpHeaders.authorizationHeader: 'Bearer ${X?.accessToken}'});
      }

      options.headers.remove('headerType');
      options.headers.addAll(header);
    }

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

    lines.add('← ${err.response?.statusCode ?? err.type.name}');
    if (err.response?.statusMessage != null) {
      lines.add('← ${err.response?.statusMessage}');
    }
    if (err.response?.data != null) {
      lines.add('← ${err.response?.data}');
    } else if (err.message != null) {
      lines.add('← ${err.message}');
    }

    XLogger.httpBlock(
      failed: true,
      title: '${opt.method.toUpperCase()} ${opt.path}',
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

    lines.add('← ${response.statusCode}');
    lines.add('← $data');

    XLogger.httpBlock(
      failed: failed,
      title: '${opt.method.toUpperCase()} ${opt.path}',
      lines: lines,
    );

    return handler.next(response);
  }
}

import 'package:dio/dio.dart';

import 'package:baseX/Core/index.dart';

import 'package:baseX/api_service/support/api_request_mixin.dart';
import 'package:baseX/api_service/support/http_type_x.dart';

enum HttpMethod { get, post, put, delete }

const String multipartHeader = 'multipart/form-data';
const Duration timeoutDuration = Duration(seconds: 60);

/// Dio-bound transport; one subclass = one connection. Override the config
/// getters and compose [interceptors] from trait mixins. See
/// doc/API_SERVICE.md.
abstract class ApiXService with ApiRequestMixin {
  late final Dio _dio;

  /// Base URL — application policy, so every connection states it explicitly.
  String get endpoint;

  /// Connect timeout.
  Duration get timeout => timeoutDuration;

  /// Status-code mapping for error handling.
  BaseXHttp get http => DefaultBaseXHttp();

  /// Interceptor stack. The base contributes nothing; each trait mixin
  /// appends its own via `[...super.interceptors, TheInterceptor()]`, so
  /// `with`-clause order = stack order.
  List<Interceptor> get interceptors => const [];

  String? get getEndpoint {
    return _dio.options.baseUrl;
  }

  /// Config getters are read once here — keep overrides constant.
  ApiXService() {
    _dio = Dio()
      ..options.connectTimeout = timeout
      ..options.baseUrl = endpoint
      ..interceptors.addAll(interceptors);

    XLogger.info('Api initialized with (${_dio.options.baseUrl}) endpoint.');
  }

  /// [get] request. Returns the raw [Response] (use `.toObject`/`.toList` to
  /// deserialise), or null on failure.
  Future<Response?> get(
    String endpoint, {
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
    bool requiredToken = true,
    String? pathParam,
    JSON? queryParam,
  }) {
    return run(
      () => _dio.get(
        mixPathParam(endpoint, pathParam: pathParam),
        queryParameters: queryParam,
        options: headerOptions(requiredToken),
      ),
      onSuccess: onSuccess,
      onError: onError,
      onTimeout: onTimeout,
      onComplete: onComplete,
    );
  }

  /// [post] request (multipart form body via [FormData]).
  Future<Response?> post(
    String endpoint,
    JSON body, {
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
    bool requiredToken = true,
    ProgressCallback? uploadProgress,
    ProgressCallback? downloadProgress,
  }) {
    return run(
      () => _dio.post(
        mixPathParam(endpoint),
        data: FormData.fromMap(body),
        options: headerOptions(requiredToken),
        onSendProgress: uploadProgress,
        onReceiveProgress: downloadProgress,
      ),
      onSuccess: onSuccess,
      onError: onError,
      onTimeout: onTimeout,
      onComplete: onComplete,
    );
  }

  /// [put] request.
  Future<Response?> put(
    String endpoint,
    JSON? body, {
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
    bool requiredToken = true,
  }) {
    return run(
      () => _dio.put(
        mixPathParam(endpoint),
        data: body,
        options: headerOptions(requiredToken),
      ),
      onSuccess: onSuccess,
      onError: onError,
      onTimeout: onTimeout,
      onComplete: onComplete,
    );
  }

  /// [delete] request.
  Future<Response?> delete(
    String endpoint,
    String pathParam, {
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
    bool requiredToken = true,
    JSON? queryParam,
  }) {
    return run(
      () => _dio.delete(
        mixPathParam(endpoint, pathParam: pathParam),
        queryParameters: queryParam,
        options: headerOptions(requiredToken),
      ),
      onSuccess: onSuccess,
      onError: onError,
      onTimeout: onTimeout,
      onComplete: onComplete,
    );
  }

  void setNewEndpoint(String endpoint) => _dio.options.baseUrl = endpoint;

  /// Close the underlying client. Prefer [ApiXConnections.dispose], which
  /// also evicts the alias so it can rebuild.
  void dispose({bool force = false}) => _dio.close(force: force);
}


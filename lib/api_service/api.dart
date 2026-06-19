part of 'index.dart';

enum HttpMethod { get, post, put, delete }

late BaseXHttp baseXHttp;

const String multipartHeader = 'multipart/form-data';
const Duration timeoutDuration = Duration(seconds: 60);

/// Dio-bound transport. Each verb is build-request → [run], which deserialises
/// the envelope, returns the parsed payload, and routes the outcome to the
/// `onSuccess` / `onError` / `onTimeout` / `onComplete` callbacks.
class ApiXService with ApiRequestMixin {
  late Dio _dio;

  void _setBaseXHttp(BaseXHttp customHttp) {
    baseXHttp = customHttp;
  }

  String? get getEndpoint {
    return _dio.options.baseUrl;
  }

  ApiXService.init(
    Dio dio,
    Duration timeout, {
    BaseXHttp? customHttp,
    String? customEndpoint,
  }) : _dio = dio {
    _dio.options.connectTimeout = timeout;

    if (customEndpoint != null) {
      _dio.options.baseUrl = customEndpoint;
    } else {
      _dio.options.baseUrl = kDebugMode ? baseConstant.uatBaseUrl : baseConstant.baseUrl;
    }

    _dio.interceptors.addAll([
      DeviceHeaderInterceptor(),
      AuthInterceptor(),
      ApiErrorInterceptor(),
      XLoggerInterceptors(),
    ]);

    if (customHttp != null) {
      _setBaseXHttp(customHttp);
    }

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
}

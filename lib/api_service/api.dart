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

  /// [get] request. [create] deserialises `data` into [T]; returns the parsed
  /// payload or null on failure.
  Future<T?> get<T>(
    String endpoint, {
    required FromJsonM<T> create,
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
    bool requiredToken = true,
    String? pathParam,
    JSON? queryParam,
  }) {
    return run<T>(
      () => _dio.get(
        mixPathParam(endpoint, pathParam: pathParam),
        queryParameters: queryParam,
        options: headerOptions(requiredToken),
      ),
      create: create,
      onSuccess: onSuccess,
      onError: onError,
      onTimeout: onTimeout,
      onComplete: onComplete,
    );
  }

  /// [post] request (multipart form body via [FormData]).
  Future<T?> post<T>(
    String endpoint,
    JSON body, {
    FromJsonM<T>? create,
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
    bool requiredToken = true,
    ProgressCallback? uploadProgress,
    ProgressCallback? downloadProgress,
  }) {
    return run<T>(
      () => _dio.post(
        mixPathParam(endpoint),
        data: FormData.fromMap(body),
        options: headerOptions(requiredToken),
        onSendProgress: uploadProgress,
        onReceiveProgress: downloadProgress,
      ),
      create: create,
      onSuccess: onSuccess,
      onError: onError,
      onTimeout: onTimeout,
      onComplete: onComplete,
    );
  }

  /// [put] request.
  Future<T?> put<T>(
    String endpoint,
    JSON? body, {
    FromJsonM<T>? create,
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
    bool requiredToken = true,
  }) {
    return run<T>(
      () => _dio.put(
        mixPathParam(endpoint),
        data: body,
        options: headerOptions(requiredToken),
      ),
      create: create,
      onSuccess: onSuccess,
      onError: onError,
      onTimeout: onTimeout,
      onComplete: onComplete,
    );
  }

  /// [delete] request.
  Future<T?> delete<T>(
    String endpoint,
    String pathParam, {
    FromJsonM<T>? create,
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
    bool requiredToken = true,
    JSON? queryParam,
  }) {
    return run<T>(
      () => _dio.delete(
        mixPathParam(endpoint, pathParam: pathParam),
        queryParameters: queryParam,
        options: headerOptions(requiredToken),
      ),
      create: create,
      onSuccess: onSuccess,
      onError: onError,
      onTimeout: onTimeout,
      onComplete: onComplete,
    );
  }

  void setNewEndpoint(String endpoint) => _dio.options.baseUrl = endpoint;
}

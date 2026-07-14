part of 'index.dart';

/// Transforms transport errors into the baseX [XError] hierarchy and rejects
/// 2xx responses that the envelope marks as logical failures.
class ApiErrorInterceptor extends Interceptor with InterceptorMixin {
  /// Request on error will throw custom Exception Error
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    DioException customError = NoConnectionException(
      requestOptions: err.requestOptions,
      response: err.response,
    );

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        customError = TimeOutException(
            requestOptions: err.requestOptions,
            response: err.response,
            errorMsg: err.response?.data['message'],
            statusCode: err.response?.statusCode);
        break;
      case DioExceptionType.badResponse:
        customError = onErrorProcess(
          err.response?.statusCode,
          err.response?.data['message'],
          err.requestOptions,
          code: err.response?.data['code'],
          response: err.response,
        );
        break;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        break;
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        customError = NoConnectionException(
          requestOptions: err.requestOptions,
          response: err.response,
          statusCode: XHttpType.unknown.value,
        );
        break;
    }

    return super.onError(customError, handler);
  }

  /// Request on response
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    if (response.data.containsKey('code') && baseConstant.success200) {
      if (response.data['code'] >= 200 && !response.data['status']) {
        return handler.reject(
          onErrorProcess(
            response.data['code'],
            response.data['message'],
            response.requestOptions,
          ),
        );
      }
    }

    return super.onResponse(response, handler);
  }
}

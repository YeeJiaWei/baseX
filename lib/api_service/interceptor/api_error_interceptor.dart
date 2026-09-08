import 'dart:io';

import 'package:dio/dio.dart';

import 'package:baseX/Core/index.dart';
import 'package:baseX/custom_error/index.dart';

import 'package:baseX/api_service/client/api_x_service.dart';
import 'package:baseX/api_service/support/http_type_x.dart';
import 'package:baseX/api_service/support/interceptor_mixin.dart';

/// Transforms transport errors into the baseX [XError] hierarchy, mapping
/// status codes with its connection's [BaseXHttp] (no shared global).
class ApiErrorInterceptor extends Interceptor with InterceptorMixin {
  final BaseXHttp http;

  ApiErrorInterceptor(this.http);

  /// Request on error will throw custom Exception Error
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    DioException customError = NoConnectionException(
      requestOptions: err.requestOptions,
      response: err.response,
    );

    // This is an `async void` override: dio calls it without awaiting and only
    // waits on `handler`, so anything thrown here escapes to the zone and
    // leaves the caller's request hanging forever. Guard the mapping (a
    // non-map error body makes `data['message']` throw) so the handler is
    // always completed exactly once.
    try {
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
            http,
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

      if (err.type == DioExceptionType.badResponse &&
          err.response?.statusCode == 401) {
        await _notifyUnauthorized(err.requestOptions);
      }
    } catch (e) {
      XLogger.error('error mapping failed: $e');
      customError = InternalServerErrorException(
        requestOptions: err.requestOptions,
        response: err.response,
        errorMsg: err.message ?? '$e',
        statusCode: err.response?.statusCode ?? XHttpType.unknown.value,
      );
    }

    return super.onError(customError, handler);
  }

  /// Raises [XAuthStore.onUnauthorized] for a request the server rejected as
  /// unauthorized — but only when the bearer it actually carried is still the
  /// cached one.
  Future<void> _notifyUnauthorized(RequestOptions options) async {
    if (options.extra['requiredToken'] != true) return;

    final store = XAuthStore.maybeInstance;
    if (store == null) return;

    final header = options.headers[HttpHeaders.authorizationHeader];
    final sentToken =
        header is String ? header.replaceFirst('Bearer ', '') : null;
    // A response that failed with an already-replaced token must not wipe the
    // newer one (e.g. an in-flight request from before a token refresh).
    if (sentToken == null || sentToken != store.cachedToken) return;

    try {
      await store.onUnauthorized();
    } catch (e) {
      XLogger.error('onUnauthorized failed: $e');
    }
  }

  /// Request on response
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final data = response.data;
    if (data is Map && data.containsKey('code') && baseConstant.success200) {
      if (data['code'] >= 200 && !data['status']) {
        final error = onErrorProcess(
          data['code'],
          data['message'],
          response.requestOptions,
          http,
        );
        // Envelope mode reports a rejected token as HTTP 200 with code 401,
        // and this rejection never reaches onError — raise the auth hook here
        // instead so the token is still cleared.
        if (error is UnauthorizedException) {
          await _notifyUnauthorized(response.requestOptions);
        }
        return handler.reject(error);
      }
    }

    return super.onResponse(response, handler);
  }
}

/// Trait: appends [ApiErrorInterceptor] (wired to the connection's
/// [ApiXService.http] mapping) to the stack.
mixin ApiErrorApiMixin on ApiXService {
  @override
  List<Interceptor> get interceptors =>
      [...super.interceptors, ApiErrorInterceptor(http)];
}

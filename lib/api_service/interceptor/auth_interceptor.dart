import 'dart:io';

import 'package:dio/dio.dart';

import 'package:baseX/Core/index.dart';

import 'package:baseX/api_service/client/api_x_service.dart';

/// Adds the Bearer token when the request opted into auth via
/// `Options(extra: {'requiredToken': true})`. The flag lives in [RequestOptions.extra],
/// so it travels to this interceptor without ever being serialised onto the wire.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['requiredToken'] == true && X != null) {
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer ${X?.accessToken}';
    }
    handler.next(options);
  }
}

/// Trait: appends [AuthInterceptor] to the connection's stack.
mixin AuthApiMixin on ApiXService {
  @override
  List<Interceptor> get interceptors =>
      [...super.interceptors, AuthInterceptor()];
}

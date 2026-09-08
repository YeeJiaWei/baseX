import 'dart:io';

import 'package:dio/dio.dart';

import 'package:baseX/Core/index.dart';

import 'package:baseX/api_service/client/api_x_service.dart';

/// Adds the Bearer token when the request opted into auth via
/// `Options(extra: {'requiredToken': true})`. The flag lives in [RequestOptions.extra],
/// so it travels to this interceptor without ever being serialised onto the wire.
///
/// The token comes from the bound [XAuthStore]; apps that have not bound one
/// yet fall back to the deprecated `X.accessToken` shared-preference path.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['requiredToken'] == true) {
      final store = XAuthStore.maybeInstance;
      // ignore: deprecated_member_use_from_same_package
      final token = store != null ? store.cachedToken : X?.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
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

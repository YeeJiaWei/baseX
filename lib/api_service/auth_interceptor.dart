part of 'index.dart';

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

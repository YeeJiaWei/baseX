part of 'index.dart';

/// Fired on a 2xx response. Always receives the [Response].
typedef OnSuccess = void Function(Response response);

/// Fired on a bad-response error (4xx/5xx). The [Response] is always present.
typedef OnError = void Function(Response response);

/// Fired when no response was received — connect/send/receive timeout or a
/// dropped/absent connection.
typedef OnTimeout = void Function();

/// Fired after every request, success or failure. Receives the [Response] when
/// one was received, otherwise null (the timeout / no-connection path).
typedef OnComplete = void Function(Response? response);

/// Cross-cutting request plumbing shared by [ApiXService]: per-request auth
/// options, path building, and the run-with-callbacks orchestration. Pure (no
/// Dio field of its own), so it stays reusable and easy to test in isolation.
mixin ApiRequestMixin {
  /// Per-request auth flag, carried in [RequestOptions.extra] (never serialised).
  /// Keeps concurrent calls isolated — [AuthInterceptor] reads it per request.
  Options headerOptions(bool requiredToken) =>
      Options(extra: {'requiredToken': requiredToken});

  /// Endpoint joined with an optional path param.
  String mixPathParam(String endpoint, {String? pathParam}) =>
      '/$endpoint${pathParam.isStringNotNullEmpty ? '/$pathParam' : ''}';

  /// Runs [request] and returns the raw [Response] (deserialise it at the call
  /// site with `.toObject` / `.toList`). Routes the outcome to the callbacks:
  /// [onSuccess] (2xx), [onError] (4xx/5xx — with the [Response]), [onTimeout]
  /// (no response at all), and [onComplete] (always). Returns null on failure.
  Future<Response?> run(
    Future<Response> Function() request, {
    OnSuccess? onSuccess,
    OnError? onError,
    OnTimeout? onTimeout,
    OnComplete? onComplete,
  }) async {
    Response? response;
    try {
      response = await request();
      onSuccess?.call(response);
      return response;
    } on Exception catch (e) {
      response = e is DioException ? e.response : null;
      if (response != null) {
        onError?.call(response);
      } else {
        onTimeout?.call();
      }
      return null;
    } finally {
      onComplete?.call(response);
    }
  }
}

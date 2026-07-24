import 'package:dio/dio.dart';

/// Builds a [T] from a decoded JSON map — the per-call deserialiser passed to
/// [XResponseX.toObject] / [XResponseX.toList]. A model's `fromJson` tear-off
/// matches this signature directly, so call sites pass `Model.fromJson`.
typedef FromJson<T> = T Function(Map<String, dynamic> json);

/// Deserialise the `{message, data}` envelope off a verb's [Response].
///
/// Every member is null-safe on [Response?]: a null receiver (a failed request,
/// where the error already went to `onError`/`onTimeout`) yields null/empty, so
/// callers can `?? []` or null-check the result.
extension XResponseX on Response? {
  /// The server message from the envelope, or '' when absent.
  String get xMessage {
    final d = this?.data;
    return d is Map && d['message'] is String ? d['message'] as String : '';
  }

  /// Parse the envelope's `data` object into a single [T] (null if absent).
  T? toObject<T>(FromJson<T> fromJson) {
    final payload = this?.data is Map ? (this!.data as Map)['data'] : null;
    return payload is Map<String, dynamic> ? fromJson(payload) : null;
  }

  /// Parse the envelope's `data` array into `List<T>` (null if it isn't a list).
  List<T>? toList<T>(FromJson<T> fromJson) {
    final payload = this?.data is Map ? (this!.data as Map)['data'] : null;
    return payload is List
        ? payload.map((e) => fromJson(e as Map<String, dynamic>)).toList()
        : null;
  }
}

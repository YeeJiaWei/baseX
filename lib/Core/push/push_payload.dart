import 'dart:convert';

import 'package:baseX/Core/logger/x_logger.dart';

/// The package-owned `payload` object carried inside a push's `data`.
class PushPayload {
  const PushPayload({
    this.type,
    this.link,
    this.deliveryId,
    this.params = const {},
  });

  /// The `data` key holding the payload.
  static const String dataKey = 'payload';

  /// Event name used to pick an event route.
  final String? type;

  /// Plain path such as `orders/1042`, routed when no event route handles the type.
  final String? link;

  /// Backend delivery id, used to drop repeat taps.
  final String? deliveryId;

  /// Event values with their real JSON types.
  final Map<String, dynamic> params;

  /// Reads the payload from [data]; the value may be a JSON string or a map, and a missing or malformed one gives an empty payload.
  factory PushPayload.fromData(Map<String, dynamic> data) {
    try {
      final raw = data[dataKey];
      if (raw == null) return const PushPayload();

      final decoded = _decode(raw);
      if (decoded == null) return const PushPayload();

      return PushPayload(
        type: _text(decoded, 'type'),
        link: _text(decoded, 'link'),
        deliveryId: _text(decoded, 'delivery_id'),
        params: _params(decoded['params']),
      );
    } catch (error) {
      _warn('payload could not be read: $error');
      return const PushPayload();
    }
  }

  static Map<String, dynamic>? _decode(Object raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is Map) return _normalizeMap(value);
      _warn('payload is not a JSON object');
    } catch (error) {
      _warn('payload is not valid JSON: $error');
    }
    return null;
  }

  static String? _text(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    _warn('payload "$key" is not a string');
    return null;
  }

  static Map<String, dynamic> _params(Object? value) {
    if (value == null) return const {};
    if (value is Map) return _normalizeMap(value);
    // PHP backends encode an empty object as []; treat it as no params.
    if (value is List && value.isEmpty) return const {};
    _warn('payload "params" is not an object');
    return const {};
  }

  static Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> source) => {
        for (final entry in source.entries)
          entry.key.toString(): _normalizeValue(entry.value),
      };

  static Object? _normalizeValue(Object? value) {
    if (value is Map) return _normalizeMap(value);
    if (value is List) return value.map(_normalizeValue).toList();
    return value;
  }

  static void _warn(String message) =>
      XLogger.warning(message, className: 'PushPayload');
}

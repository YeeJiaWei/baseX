part of 'index.dart';

/// [XData] is a base model to make sure extended classes have these method implmented
abstract class XData {
  XData();

  JSON toJson();

  /// Deserialise a JSON list into a typed model list.
  ///
  /// Dart can't reach a subclass's `fromJson` from the base class (no `Self`
  /// type, no constructor-bound generics, no reflection), so the per-model
  /// `fromJson` is passed in:
  ///
  /// ```dart
  /// XData.listFromJson(data, User.fromJson)
  /// ```
  static List<T> listFromJson<T>(
    List? data,
    T Function(JSON) fromJson,
  ) =>
      (data ?? const []).whereType<JSON>().map(fromJson).toList();
}

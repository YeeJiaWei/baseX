import 'dart:core' as core;
import 'dart:core';

/// A validator for one payload param.
class LinkParam {
  const LinkParam(this._isValid);

  final core.bool Function(core.String value) _isValid;

  /// A whole number; real ints and numeric strings such as "1042" pass.
  static const LinkParam int = LinkParam(_isInt);

  /// Any non-empty value.
  static const LinkParam string = LinkParam(_isNotEmpty);

  /// Whether [value] is present and passes this validator.
  core.bool accepts(core.Object? value) {
    if (value == null) return false;
    return _isValid(value.toString());
  }

  static core.bool _isInt(core.String value) =>
      core.int.tryParse(value) != null;

  static core.bool _isNotEmpty(core.String value) => value.isNotEmpty;
}

import 'package:baseX/Core/notification_links/link_segment_kind.dart';

/// One parsed segment of a [LinkPattern].
class LinkSegment {
  const LinkSegment({
    required this.kind,
    this.name,
    this.text,
    this.allowed,
    this.numeric = false,
  });

  final LinkSegmentKind kind;
  final String? name;

  /// The exact text of a literal segment.
  final String? text;

  /// The fixed list of a `{name:a|b}` segment.
  final Set<String>? allowed;

  /// True for a `{name:int}` segment.
  final bool numeric;

  /// Whether [value] is acceptable for this segment.
  bool accepts(String value) {
    switch (kind) {
      case LinkSegmentKind.literal:
        return value == text;
      case LinkSegmentKind.constrained:
        return numeric ? int.tryParse(value) != null : allowed!.contains(value);
      default:
        return true;
    }
  }

  /// Whether some value could satisfy both this segment and [other] (same kind).
  bool overlaps(LinkSegment other) {
    if (kind == LinkSegmentKind.literal) return text == other.text;
    if (kind != LinkSegmentKind.constrained) return true;
    if (numeric && other.numeric) return true;
    if (numeric) return other.allowed!.any(accepts);
    if (other.numeric) return allowed!.any(other.accepts);
    return allowed!.intersection(other.allowed!).isNotEmpty;
  }
}

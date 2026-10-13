import 'package:baseX/Core/notification_links/link_pattern_match.dart';
import 'package:baseX/Core/notification_links/link_segment.dart';
import 'package:baseX/Core/notification_links/link_segment_kind.dart';

/// A parsed path pattern such as `orders/{id:int}` or `help/**`.
class LinkPattern {
  const LinkPattern._(this.source, this.segments);

  final String source;
  final List<LinkSegment> segments;

  /// Parses [source]; throws a [FormatException] on invalid syntax.
  factory LinkPattern.parse(String source) {
    final parts = _split(source);
    final segments = <LinkSegment>[];
    final names = <String>{};

    for (var index = 0; index < parts.length; index++) {
      final segment = _parseSegment(parts[index], source);
      final isLast = index == parts.length - 1;
      final mustBeLast = segment.kind == LinkSegmentKind.optional ||
          segment.kind == LinkSegmentKind.rest;
      if (mustBeLast && !isLast) {
        throw FormatException(
          'Pattern "$source": "${parts[index]}" must be the last segment',
        );
      }
      final name = segment.name;
      if (name != null && !names.add(name)) {
        throw FormatException('Pattern "$source": duplicate param "$name"');
      }
      segments.add(segment);
    }

    return LinkPattern._(source, List.unmodifiable(segments));
  }

  /// The path segments of a notification link, host first.
  static List<String> pathSegmentsOf(Uri uri) => [
        if (uri.host.isNotEmpty) uri.host,
        ...uri.pathSegments.where((segment) => segment.isNotEmpty),
      ];

  static List<String> _split(String text) =>
      text.split('/').where((part) => part.isNotEmpty).toList();

  static LinkSegment _parseSegment(String part, String source) {
    if (part == '**') return const LinkSegment(kind: LinkSegmentKind.rest);
    if (part == '*') return const LinkSegment(kind: LinkSegmentKind.any);

    final isParam = part.startsWith('{') && part.endsWith('}');
    if (!isParam) {
      if (part.contains('{') || part.contains('}')) {
        throw FormatException('Pattern "$source": bad segment "$part"');
      }
      return LinkSegment(kind: LinkSegmentKind.literal, text: part);
    }

    var inner = part.substring(1, part.length - 1);
    final isOptional = inner.endsWith('?');
    if (isOptional) inner = inner.substring(0, inner.length - 1);

    final colon = inner.indexOf(':');
    final name = colon == -1 ? inner : inner.substring(0, colon);
    if (name.isEmpty) {
      throw FormatException('Pattern "$source": unnamed param "$part"');
    }

    if (colon == -1) {
      return LinkSegment(
        kind: isOptional ? LinkSegmentKind.optional : LinkSegmentKind.plain,
        name: name,
      );
    }
    if (isOptional) {
      throw FormatException(
        'Pattern "$source": optional param "$part" cannot be constrained',
      );
    }

    final constraint = inner.substring(colon + 1);
    if (constraint == 'int') {
      return LinkSegment(
        kind: LinkSegmentKind.constrained,
        name: name,
        numeric: true,
      );
    }
    final allowed = constraint.split('|').where((value) => value.isNotEmpty).toSet();
    if (allowed.isEmpty) {
      throw FormatException('Pattern "$source": empty list in "$part"');
    }
    return LinkSegment(
      kind: LinkSegmentKind.constrained,
      name: name,
      allowed: allowed,
    );
  }

  /// Matches [path] against this pattern, or returns null.
  LinkPatternMatch? match(List<String> path) {
    final params = <String, String>{};
    var rest = <String>[];
    var index = 0;

    for (final segment in segments) {
      switch (segment.kind) {
        case LinkSegmentKind.rest:
          rest = path.sublist(index);
          index = path.length;
        case LinkSegmentKind.optional:
          if (index < path.length) params[segment.name!] = path[index++];
        default:
          if (index >= path.length || !segment.accepts(path[index])) {
            return null;
          }
          final name = segment.name;
          if (name != null) params[name] = path[index];
          index++;
      }
    }

    return index == path.length
        ? LinkPatternMatch(params: params, rest: rest)
        : null;
  }

  /// Negative when this pattern is more specific than [other], positive when less.
  int compareSpecificity(LinkPattern other) {
    final length = segments.length > other.segments.length
        ? segments.length
        : other.segments.length;
    for (var index = 0; index < length; index++) {
      final mine = _rankAt(index);
      final theirs = other._rankAt(index);
      if (mine != theirs) return mine - theirs;
    }
    return 0;
  }

  int _rankAt(int index) => index < segments.length
      ? segments[index].kind.index
      : LinkSegmentKind.missing.index;

  /// Whether this and [other] tie on every segment and could match the same link.
  bool conflictsWith(LinkPattern other) {
    if (compareSpecificity(other) != 0) return false;
    for (var index = 0; index < segments.length; index++) {
      if (!segments[index].overlaps(other.segments[index])) return false;
    }
    return true;
  }
}

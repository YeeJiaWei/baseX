/// Values captured when a [LinkPattern] matches a path.
class LinkPatternMatch {
  const LinkPatternMatch({required this.params, required this.rest});

  final Map<String, String> params;
  final List<String> rest;
}

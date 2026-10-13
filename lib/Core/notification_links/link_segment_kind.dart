/// Segment kinds in precedence order: a lower index is more specific.
enum LinkSegmentKind {
  literal,
  constrained,
  plain,

  /// Stands for "no segment here" when patterns of different length are compared.
  missing,
  optional,
  any,
  rest,
}

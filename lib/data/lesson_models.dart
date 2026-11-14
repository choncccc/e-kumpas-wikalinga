/// A single sign to learn, e.g. "Letter A" or "Where does it hurt?".
class Sign {
  const Sign({
    required this.id,
    required this.term,
    this.signOrder,
    this.facialExpression,
  });

  final int id;
  final String term;

  /// Gloss order for phrases, e.g. "HURT + WHERE?".
  final String? signOrder;

  /// Grammar cue, e.g. "WH question: furrow eyebrows".
  final String? facialExpression;

  factory Sign.fromRow(Map<String, Object?> r) => Sign(
    id: r['id'] as int,
    term: r['term'] as String,
    signOrder: r['sign_order'] as String?,
    facialExpression: r['facial_expression'] as String?,
  );
}

/// A group of signs inside a category, e.g. "Alphabet" or "Chief Complaints".
class LessonTopic {
  const LessonTopic({
    required this.id,
    required this.title,
    required this.signs,
  });

  final int id;
  final String title;
  final List<Sign> signs;
}

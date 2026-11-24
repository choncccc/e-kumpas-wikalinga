/// A single sign to learn, e.g. "Letter A" or "Where does it hurt?".
class Sign {
  const Sign({
    required this.id,
    required this.key,
    required this.term,
    this.tagalog,
    this.signOrder,
    this.facialExpression,
    this.media,
  });

  /// Row id. Changes whenever the lesson content is reseeded, so never store
  /// it; use [key] instead.
  final int id;

  /// Stable identity that survives reseeding: bookmarks and progress use it.
  final String key;
  final String term;

  /// Filipino translation, e.g. "Saan ang masakit?". Null for letters and
  /// other terms that don't translate.
  final String? tagalog;

  /// Gloss order for phrases, e.g. "HURT + WHERE?".
  final String? signOrder;

  /// Grammar cue, e.g. "WH question: furrow eyebrows".
  final String? facialExpression;

  /// Bundled asset showing the sign: a .mp4 clip or a .jpg still. Null when
  /// there's no recording yet.
  final String? media;

  bool get hasVideo => media?.endsWith('.mp4') ?? false;

  /// A still of the sign: the photo itself, or the poster frame that
  /// tool/build_media.py writes next to every clip.
  String? get poster =>
      hasVideo ? '${media!.substring(0, media!.length - 4)}.jpg' : media;

  static String keyFor(String categoryId, String topicTitle, String term) =>
      '$categoryId/$topicTitle/$term';

  factory Sign.fromRow(Map<String, Object?> r) => Sign(
    id: r['id'] as int,
    key: r['sign_key'] as String,
    term: r['term'] as String,
    tagalog: r['tagalog'] as String?,
    signOrder: r['sign_order'] as String?,
    facialExpression: r['facial_expression'] as String?,
    media: r['media'] as String?,
  );
}

/// A group of signs inside a category, e.g. "Alphabet" or "Chief Complaints".
class LessonTopic {
  const LessonTopic({
    required this.id,
    required this.title,
    required this.signs,
    this.tagalog,
  });

  final int id;
  final String title;
  final List<Sign> signs;

  /// Filipino title, e.g. "Mga Gamot".
  final String? tagalog;
}

/// A sign together with where it lives, for search results and bookmarks.
class SignEntry {
  const SignEntry({
    required this.sign,
    required this.categoryId,
    required this.topicId,
    required this.topicTitle,
  });

  final Sign sign;
  final String categoryId;
  final int topicId;
  final String topicTitle;

  factory SignEntry.fromRow(Map<String, Object?> r) => SignEntry(
    sign: Sign.fromRow(r),
    categoryId: r['category_id'] as String,
    topicId: r['topic_id'] as int,
    topicTitle: r['topic_title'] as String,
  );
}

/// How much of a category the learner has looked at.
class CategoryProgress {
  const CategoryProgress({required this.viewed, required this.total});

  final int viewed;
  final int total;

  double get fraction => total == 0 ? 0 : viewed / total;
}

/// A topic the learner studied recently, newest first.
class RecentTopic {
  const RecentTopic({
    required this.categoryId,
    required this.topicId,
    required this.topicTitle,
    required this.lastViewed,
  });

  final String categoryId;
  final int topicId;
  final String topicTitle;
  final DateTime lastViewed;
}

/// One line of the on-device activity log: something the learner opened or
/// tapped, e.g. ("Opened Topic", "Vital Signs").
class ActivityEntry {
  const ActivityEntry({required this.at, required this.action, this.detail});

  final DateTime at;
  final String action;
  final String? detail;
}

/// A score on one quiz.
class QuizScore {
  const QuizScore(this.score, this.total);

  final int score;
  final int total;
}

/// Summary of finished quizzes.
class QuizStats {
  const QuizStats({
    required this.taken,
    required this.bestScore,
    required this.bestTotal,
    required this.lastScore,
    required this.lastTotal,
  });

  final int taken;
  final int bestScore;
  final int bestTotal;
  final int lastScore;
  final int lastTotal;
}

import 'package:ekumpas_wikalinga/data/lesson_models.dart';
import 'package:ekumpas_wikalinga/data/lesson_repository.dart';
import 'package:ekumpas_wikalinga/data/study_repository.dart';

Sign sign(int id, String term, {String? order, String? face}) => Sign(
  id: id,
  key: 'foundation/t/$term',
  term: term,
  signOrder: order,
  facialExpression: face,
);

/// Two small topics, the same for every category.
class FakeLessonRepository implements LessonRepository {
  static final topics = [
    LessonTopic(
      id: 1,
      title: 'Alphabet',
      signs: [sign(1, 'Letter A'), sign(2, 'Letter B')],
    ),
    LessonTopic(
      id: 2,
      title: 'Questions',
      signs: [
        sign(
          3,
          'What is your name?',
          order: 'YOUR + NAME + WHAT?',
          face: 'WH question: furrow eyebrows',
        ),
        sign(
          4,
          'Are you dizzy?',
          order: 'YOU + DIZZY + FEEL?',
          face: 'Yes/no question: raise eyebrows',
        ),
      ],
    ),
  ];

  static List<SignEntry> get entries => [
    for (final t in topics)
      for (final s in t.signs)
        SignEntry(
          sign: s,
          categoryId: 'foundation',
          topicId: t.id,
          topicTitle: t.title,
        ),
  ];

  @override
  Future<List<LessonTopic>> topicsFor(String categoryId) async => topics;

  @override
  Future<LessonTopic?> topic(int topicId) async =>
      topics.where((t) => t.id == topicId).firstOrNull;

  @override
  Future<List<SignEntry>> search(String query, {int limit = 60}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return entries
        .where((e) => e.sign.term.toLowerCase().contains(q))
        .take(limit)
        .toList();
  }

  @override
  Future<List<SignEntry>> allSigns() async => entries;
}

class FakeStudyRepository extends StudyRepository {
  final bookmarked = <String>[];
  final viewed = <String, DateTime>{};
  final quizzes = <(int, int, String?)>[];
  final levels = <int, Duration>{};
  final log = <ActivityEntry>[];

  @override
  Future<Set<String>> bookmarkedKeys() async => bookmarked.toSet();

  @override
  Future<List<SignEntry>> bookmarks() async => [
    for (final k in bookmarked.reversed)
      ...FakeLessonRepository.entries.where((e) => e.sign.key == k),
  ];

  @override
  Future<void> setBookmarked(String signKey, bool on) async {
    bookmarked.remove(signKey);
    if (on) bookmarked.add(signKey);
    notifyListeners();
  }

  @override
  Future<void> markViewed(String signKey) async {
    viewed[signKey] = DateTime.now();
    notifyListeners();
  }

  @override
  Future<Map<String, CategoryProgress>> progress() async => {
    'foundation': CategoryProgress(
      viewed: viewed.length,
      total: FakeLessonRepository.entries.length,
    ),
  };

  @override
  Future<List<RecentTopic>> recentTopics({int limit = 3}) async => [
    if (viewed.isNotEmpty)
      RecentTopic(
        categoryId: 'foundation',
        topicId: 1,
        topicTitle: 'Alphabet',
        lastViewed: viewed.values.last,
      ),
  ];

  @override
  Future<int> signsViewedSince(DateTime since) async =>
      viewed.values.where((t) => !t.isBefore(since)).length;

  @override
  Future<void> saveQuizResult(int score, int total, {String? quizId}) async {
    quizzes.add((score, total, quizId));
    notifyListeners();
  }

  @override
  Future<Map<String, QuizScore>> bestQuizScores() async {
    final best = <String, QuizScore>{};
    for (final (score, total, id) in quizzes) {
      final b = id == null ? null : best[id];
      if (id != null && (b == null || score / total > b.score / b.total)) {
        best[id] = QuizScore(score, total);
      }
    }
    return best;
  }

  @override
  Future<QuizStats?> quizStats() async => quizzes.isEmpty
      ? null
      : QuizStats(
          taken: quizzes.length,
          bestScore: quizzes.first.$1,
          bestTotal: quizzes.first.$2,
          lastScore: quizzes.last.$1,
          lastTotal: quizzes.last.$2,
        );

  @override
  Future<void> saveGameLevel(int level, Duration time) async {
    final best = levels[level];
    if (best == null || time < best) levels[level] = time;
    notifyListeners();
  }

  @override
  Future<Map<int, Duration>> gameLevels() async => Map.of(levels);

  @override
  Future<void> logActivity(String action, [String? detail]) async => log.add(
    ActivityEntry(at: DateTime.now(), action: action, detail: detail),
  );

  @override
  Future<List<ActivityEntry>> activity({int limit = 2000}) async =>
      log.reversed.take(limit).toList();

  @override
  Future<void> clearActivity() async {
    log.clear();
    notifyListeners();
  }
}

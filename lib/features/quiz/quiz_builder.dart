import 'dart:math';

import '../../data/lesson_models.dart';

enum QuestionKind { watchSign, signOrder, facialExpression, grammar }

class QuizQuestion {
  const QuizQuestion({
    required this.kind,
    required this.prompt,
    required this.hint,
    required this.options,
    required this.correct,
    required this.explanation,
    this.subject,
    this.media,
  });

  final QuestionKind kind;
  final String prompt;
  final String hint;

  /// The term the question is about, shown large (e.g. "Where does it hurt?").
  final String? subject;
  final List<String> options;
  final int correct;

  /// Shown after answering.
  final String explanation;

  /// Sign clip or still to identify, for [QuestionKind.watchSign].
  final String? media;

  /// What the question is about, so a quiz never asks about the same phrase
  /// twice. Null for general grammar questions.
  String? get about =>
      kind == QuestionKind.watchSign ? options[correct] : subject;
}

/// Builds a quiz from the lesson content: mostly "What is being signed?"
/// (the mockup's main question), plus sign order, facial grammar and the
/// home page tips.
class QuizBuilder {
  QuizBuilder(this.signs, {Random? random}) : _random = random ?? Random();

  final List<SignEntry> signs;
  final Random _random;

  static const length = 10;

  static const furrow = 'Furrow eyebrows (WH question)';
  static const raise = 'Raise eyebrows (yes/no question)';
  static const neutral = 'Neutral face (statement)';

  List<QuizQuestion> build({int count = length}) {
    final watch = _shuffled(
      signs.where((e) => e.sign.media != null),
    ).map(_watchQuestion).whereType<QuizQuestion>();
    final order = _shuffled(signs.where(_hasOrderQuestion)).map(_orderQuestion);
    final face = _shuffled(
      signs.where((e) => _faceAnswer(e.sign) != null),
    ).map(_faceQuestion);
    final grammar = _shuffled(_grammarBank).map(_withShuffledOptions);

    // Aim for a mix (4 watch, 2 order, 2 face, 2 grammar), topping up from
    // whichever pools still have questions if one runs short. Pools are in
    // QuestionKind order.
    final pools = [
      watch.iterator,
      order.iterator,
      face.iterator,
      grammar.iterator,
    ];
    final targets = [count * 4 ~/ 10, count * 2 ~/ 10, count * 2 ~/ 10, count];
    final picked = <QuizQuestion>[];
    // One question per phrase, so a quiz never asks about the same one twice.
    final subjects = <String>{};
    bool take(Iterator<QuizQuestion> pool) {
      while (pool.moveNext()) {
        final q = pool.current;
        if (q.about == null || subjects.add(q.about!)) {
          picked.add(q);
          return true;
        }
      }
      return false;
    }

    for (var p = 0; p < pools.length; p++) {
      while (picked.length < count &&
          picked.where((q) => q.kind.index == p).length < targets[p] &&
          take(pools[p])) {}
    }
    for (final pool in pools) {
      while (picked.length < count && take(pool)) {}
    }
    return _shuffled(picked);
  }

  List<T> _shuffled<T>(Iterable<T> items) => items.toList()..shuffle(_random);

  // ---- Watch the sign ----

  /// "What is being signed?" with three other terms as distractors, taken
  /// from the same topic when it has enough so they look alike (letters with
  /// letters, body parts with body parts). Null if there aren't enough.
  QuizQuestion? _watchQuestion(SignEntry e) {
    final term = e.sign.term;
    Iterable<String> others(bool Function(SignEntry o) near) => signs
        .where((o) => o.sign.term != term && near(o))
        .map((o) => o.sign.term)
        .toSet();
    final pool = [
      others(
        (o) => o.topicTitle == e.topicTitle && o.categoryId == e.categoryId,
      ),
      others((o) => o.categoryId == e.categoryId),
      others((_) => true),
    ].firstWhere((p) => p.length >= 3, orElse: () => const []);
    if (pool.isEmpty) return null;

    final options = _shuffled([term, ..._shuffled(pool).take(3)]);
    final tagalog = e.sign.tagalog;
    return QuizQuestion(
      kind: QuestionKind.watchSign,
      prompt: 'What is being signed?',
      hint: 'Watch the sign carefully.',
      media: e.sign.media,
      options: options,
      correct: options.indexOf(term),
      explanation: tagalog == null
          ? 'That was “$term”.'
          : 'That was “$term” ($tagalog).',
    );
  }

  // ---- Sign order ----

  static List<String> _tokens(String order) =>
      order.replaceAll('?', '').split(' + ').map((t) => t.trim()).toList();

  static bool _hasOrderQuestion(SignEntry e) {
    final order = e.sign.signOrder;
    return order != null && _tokens(order).toSet().length >= 3;
  }

  QuizQuestion _orderQuestion(SignEntry e) {
    final order = e.sign.signOrder!;
    final isQuestion = order.trim().endsWith('?');
    final tokens = _tokens(order);
    String render(List<String> t) => t.join(' + ') + (isQuestion ? '?' : '');

    final correct = render(tokens);
    final options = <String>{correct};
    // Wrong orders of the same signs. 3+ distinct tokens give at least 5.
    for (var tries = 0; options.length < 4 && tries < 60; tries++) {
      options.add(render(_shuffled(tokens)));
    }
    final list = _shuffled(options);
    return QuizQuestion(
      kind: QuestionKind.signOrder,
      prompt: 'Which is the correct FSL sign order?',
      hint: 'Pick the order a Deaf patient would see.',
      subject: e.sign.term,
      options: list,
      correct: list.indexOf(correct),
      explanation: isQuestion && _whWord(tokens.last)
          ? 'Question words go at the end: $correct'
          : 'Signed as $correct',
    );
  }

  static bool _whWord(String token) =>
      RegExp(r'^(WHAT|WHERE|WHEN|WHO|WHY|HOW)').hasMatch(token);

  // ---- Facial expression ----

  static String? _faceAnswer(Sign s) {
    final f = s.facialExpression?.toLowerCase();
    if (f == null) return null;
    if (f.contains('wh')) return furrow;
    if (f.contains('yes/no') || f.contains('raise')) return raise;
    return null;
  }

  QuizQuestion _faceQuestion(SignEntry e) {
    final answer = _faceAnswer(e.sign)!;
    const options = [furrow, raise, neutral];
    return QuizQuestion(
      kind: QuestionKind.facialExpression,
      prompt: 'Which facial expression goes with this?',
      hint: 'In FSL your face is part of the grammar.',
      subject: e.sign.term,
      options: options,
      correct: options.indexOf(answer),
      explanation: answer == furrow
          ? 'It asks for information (a WH question), so furrow your eyebrows.'
          : 'It’s answered with yes or no, so raise your eyebrows.',
    );
  }

  // ---- Grammar rules (the home page tips) ----

  QuizQuestion _withShuffledOptions(QuizQuestion q) {
    final answer = q.options[q.correct];
    final options = _shuffled(q.options);
    return QuizQuestion(
      kind: q.kind,
      prompt: q.prompt,
      hint: q.hint,
      subject: q.subject,
      media: q.media,
      options: options,
      correct: options.indexOf(answer),
      explanation: q.explanation,
    );
  }

  static const _grammarBank = [
    QuizQuestion(
      kind: QuestionKind.grammar,
      prompt: 'Where do question words like WHAT, WHERE and WHY go?',
      hint: 'FSL grammar',
      options: [
        'At the end of the sentence',
        'At the start of the sentence',
        'Right after the subject',
        'Anywhere, it doesn’t matter',
      ],
      correct: 0,
      explanation: 'WH question words are signed at the very end.',
    ),
    QuizQuestion(
      kind: QuestionKind.grammar,
      prompt: 'Where in the sentence do you sign when something happened?',
      hint: 'FSL grammar',
      options: [
        'At the very beginning',
        'At the very end',
        'Right after the verb',
        'Time is never signed',
      ],
      correct: 0,
      explanation: 'Time goes first, so the scene is set before anything else.',
    ),
    QuizQuestion(
      kind: QuestionKind.grammar,
      prompt: 'Which of these words does FSL leave out?',
      hint: 'FSL grammar',
      options: ['the', 'doctor', 'pain', 'medicine'],
      correct: 0,
      explanation:
          'Little connecting words (is, are, the, a, of) are skipped. Only the '
          'key words are signed.',
    ),
    QuizQuestion(
      kind: QuestionKind.grammar,
      prompt: 'What do raised eyebrows usually show?',
      hint: 'Facial grammar',
      options: [
        'A yes/no question',
        'A WH question',
        'A plain statement',
        'That you disagree',
      ],
      correct: 0,
      explanation:
          'Raised eyebrows mark a yes/no question; furrowed ones mark a WH '
          'question.',
    ),
    QuizQuestion(
      kind: QuestionKind.grammar,
      prompt: 'Describing an event, what do you establish first?',
      hint: 'FSL grammar',
      options: [
        'Where it happened',
        'How you felt about it',
        'The question word',
        'Your own name',
      ],
      correct: 0,
      explanation:
          'Place goes first: set the location, then describe the action.',
    ),
    QuizQuestion(
      kind: QuestionKind.grammar,
      prompt: 'In topic-comment structure, what comes first?',
      hint: 'FSL grammar',
      options: [
        'The topic (the main subject)',
        'The comment (what happens to it)',
        'The question word',
        'The verb',
      ],
      correct: 0,
      explanation: 'State the topic first, then the comment about it.',
    ),
  ];
}

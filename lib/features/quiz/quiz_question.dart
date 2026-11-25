import 'dart:math';

import '../../data/quiz_content.dart';

/// One question as the quiz screen shows it.
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.hint,
    required this.options,
    required this.correct,
    required this.explanation,
    this.media,
  });

  /// "What sign language is being demonstrated?" for a quiz item, as worded
  /// in the client's quizzes. With [random] the options are dealt in a new
  /// order (so a retake isn't just the same letters again); without it they
  /// stay in the answer key's A–D order.
  factory QuizQuestion.fromItem(QuizItem item, {Random? random}) {
    final answer = item.options[item.answer];
    final options = [...item.options];
    if (random != null) options.shuffle(random);
    final still = item.media?.endsWith('.jpg') ?? false;
    return QuizQuestion(
      prompt: 'What sign language is being demonstrated?',
      hint: still
          ? 'Look closely at the handshape.'
          : 'Watch the sign carefully.',
      media: item.media,
      options: options,
      correct: options.indexOf(answer),
      explanation: 'The answer is “$answer”.',
    );
  }

  final String prompt;
  final String hint;
  final List<String> options;
  final int correct;

  /// Shown after answering.
  final String explanation;

  /// Sign clip or still to identify.
  final String? media;
}

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
  /// in the client's quizzes. Options stay in their A–D order.
  factory QuizQuestion.fromItem(QuizItem item) {
    final answer = item.options[item.answer];
    final still = item.media?.endsWith('.jpg') ?? false;
    return QuizQuestion(
      prompt: 'What sign language is being demonstrated?',
      hint: still
          ? 'Look closely at the handshape.'
          : 'Watch the sign carefully.',
      media: item.media,
      options: item.options,
      correct: item.answer,
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

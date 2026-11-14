import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// How each lesson category looks on screen, plus the home-page tips. Both
/// come from prototype/contents/App-Content.pdf. The categories' topics and
/// signs live in SQLite (see SqliteLessonRepository); ids match lessons.json.
class LessonCategory {
  const LessonCategory({
    required this.id,
    required this.title,
    required this.fullTitle,
    required this.icon,
    required this.color,
  });

  final String id;

  /// Short label shown on the home tile.
  final String title;

  /// Section name from the content document.
  final String fullTitle;
  final IconData icon;
  final Color color;
}

class SignTip {
  const SignTip(this.title, this.body);
  final String title;
  final String body;
}

abstract final class LearningContent {
  static const categories = <LessonCategory>[
    LessonCategory(
      id: 'foundation',
      title: 'Foundation',
      fullTitle: 'Foundational Vocabulary',
      icon: Icons.abc_rounded,
      color: AppColors.teal,
    ),
    LessonCategory(
      id: 'basic',
      title: 'Basic',
      fullTitle: 'Basic Conversational Signs',
      icon: Icons.sign_language_rounded,
      color: AppColors.teal,
    ),
    LessonCategory(
      id: 'triage',
      title: 'Triage & Vitals',
      fullTitle: 'Basic Medical and Triage Information',
      icon: Icons.monitor_heart_rounded,
      color: AppColors.sage,
    ),
    LessonCategory(
      id: 'medical_family',
      title: 'Medical & Family',
      fullTitle: 'Medical & Family History',
      icon: Icons.medical_information_rounded,
      color: AppColors.sage,
    ),
    LessonCategory(
      id: 'nutrition',
      title: 'Nutrition & Lifestyle',
      fullTitle: 'Nutritional & Lifestyle History',
      icon: Icons.restaurant_rounded,
      color: AppColors.mint,
    ),
    LessonCategory(
      id: 'procedures',
      title: 'Procedures & Advice',
      fullTitle: 'Procedures & Health Advice',
      icon: Icons.vaccines_rounded,
      color: AppColors.mint,
    ),
  ];

  static const tips = <SignTip>[
    SignTip(
      'Time Goes First',
      'In Filipino Sign Language (FSL), always sign when something happened at the '
          'very beginning of your sentence.',
    ),
    SignTip(
      'Place Goes First',
      'Establish the location before describing the action or event. This helps set '
          'the visual scene right away.',
    ),
    SignTip(
      'Topic-Comment Structure',
      'State the main subject (the Topic) first, then describe what is happening to it '
          '(the Comment).',
    ),
    SignTip(
      '“WH-” Questions Go at the End',
      'Question words like Who, What, Where, When, and Why are always signed at the '
          'very end of the sentence.',
    ),
    SignTip(
      'No “Little” Words',
      'FSL skips connecting words like is, are, the, a, am, and of. Focus only on the '
          'key action and meaning words.',
    ),
    SignTip(
      'Facial Expressions = Grammar',
      'Your face is half the language. Raising or lowering your eyebrows shows whether '
          'you are asking a question or making a statement.',
    ),
  ];
}

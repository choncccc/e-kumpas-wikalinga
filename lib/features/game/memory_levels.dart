import '../../data/lesson_models.dart';

/// Clock for a level: five minutes for level 1, one more for each level
/// after (client request, Nov 2026).
Duration levelTimeLimit(int level) => Duration(minutes: 4 + level);

/// One pair in a level: the lesson sign whose recording goes on the blue
/// card, and optionally shorter wording for the green card.
class MemoryItem {
  const MemoryItem(this.categoryId, this.topic, this.term, {this.label});

  final String categoryId;
  final String topic;
  final String term;

  /// Green card text when it should differ from the lesson term, e.g.
  /// "120/80" for "Normal BP: Below 120/80".
  final String? label;

  String get key => Sign.keyFor(categoryId, topic, term);
}

/// A level ready to play: ten signs, each with its card text.
class MemoryLevel {
  const MemoryLevel({
    required this.number,
    required this.title,
    required this.pairs,
  });

  final int number;
  final String title;
  final List<MemoryPair> pairs;
}

class MemoryPair {
  const MemoryPair({required this.sign, required this.label});

  final Sign sign;
  final String label;
}

/// The six rounds from the game section of App-Content.pdf, one per lesson
/// category. Where a listed word has no recording, the closest sign that has
/// one stands in (noted below).
const memoryLevelSpecs = <(String, List<MemoryItem>)>[
  (
    'Foundation',
    [
      MemoryItem('foundation', 'Alphabet', 'Letter F'),
      MemoryItem('foundation', 'Alphabet', 'Letter M'),
      MemoryItem('foundation', 'Numbers', 'Number 7', label: '7'),
      // The PDF lists "120"; there's no recording of it.
      MemoryItem('foundation', 'Numbers', 'Number 100', label: '100'),
      // "Morning" and "Evening": the greetings are the closest recordings.
      MemoryItem('basic', 'Common Greetings & Introduction', 'Good morning'),
      MemoryItem('basic', 'Common Greetings & Introduction', 'Good evening'),
      MemoryItem('foundation', 'Dates', 'Monday'),
      MemoryItem('foundation', 'Dates', 'January'),
      MemoryItem('foundation', 'Colors', 'Red'),
      MemoryItem('foundation', 'Colors', 'Blue'),
    ],
  ),
  (
    'Conversation',
    [
      MemoryItem('basic', 'Common Greetings & Introduction', 'Hello'),
      MemoryItem('basic', 'Common Greetings & Introduction', 'Welcome'),
      MemoryItem('basic', 'Courtesies', 'Thank you'),
      MemoryItem('basic', 'Courtesies', 'Sorry'),
      MemoryItem('basic', 'Simple Responses', 'Yes'),
      MemoryItem('basic', 'Simple Responses', 'No'),
      MemoryItem('basic', 'Questions', 'What?'),
      MemoryItem('basic', 'Questions', 'Where?'),
      MemoryItem('basic', 'Questions', 'When?'),
      MemoryItem('basic', 'Questions', 'How?'),
    ],
  ),
  (
    'Triage & Vitals',
    [
      MemoryItem(
        'triage',
        'Vital Signs',
        'Blood Pressure / BP',
        label: 'Blood Pressure',
      ),
      MemoryItem('triage', 'Vital Signs', 'Temperature'),
      MemoryItem(
        'triage',
        'Blood Pressure Values',
        'Normal BP: Below 120/80',
        label: '120/80',
      ),
      MemoryItem(
        'triage',
        'Blood Pressure Values',
        'Emergency BP: Above 180/120',
        label: '180/120',
      ),
      MemoryItem('triage', 'Chief Complaints', 'Wound / Cut / Injury'),
      MemoryItem('triage', 'Chief Complaints', 'Pain / Ache'),
      MemoryItem(
        'triage',
        'Red-Flag Symptoms (Hypertension)',
        'Shortness of Breath / Difficulty Breathing',
        label: 'Shortness of Breath',
      ),
      MemoryItem(
        'triage',
        'Red-Flag Symptoms (Hypertension)',
        'Chest Pain / Tightness',
      ),
      MemoryItem('triage', 'Healthcare Roles and Areas', 'Nurse'),
      MemoryItem('triage', 'Healthcare Roles and Areas', 'Doctor'),
    ],
  ),
  (
    'Medical & Family',
    [
      MemoryItem('medical_family', 'Family Relationships', 'Mother'),
      MemoryItem('medical_family', 'Family Relationships', 'Single'),
      MemoryItem('medical_family', 'General Health History', 'Healthy'),
      // "Past Illness / Previous Disease" has no recording; "Sick" is closest.
      MemoryItem('medical_family', 'General Health History', 'Sick'),
      MemoryItem(
        'medical_family',
        'Hypertension-Related Conditions',
        'High Blood Pressure / Hypertension',
        label: 'Hypertension',
      ),
      MemoryItem(
        'medical_family',
        'Hypertension-Related Conditions',
        'Diabetes / High Sugar',
      ),
      // "Medicine" and "Allergy" stand-ins.
      MemoryItem('medical_family', 'Medications', 'Maintenance Medicine'),
      MemoryItem('medical_family', 'Medications', 'Vaccination'),
      MemoryItem(
        'medical_family',
        'Allergies',
        'Drug / Medicine Allergy',
        label: 'Medicine Allergy',
      ),
      MemoryItem('medical_family', 'Allergies', 'Itching'),
    ],
  ),
  (
    'Nutrition & Lifestyle',
    [
      MemoryItem('nutrition', 'Dietary Habits', 'Salty Food'),
      MemoryItem('nutrition', 'Dietary Habits', 'Sweet Food'),
      MemoryItem('nutrition', 'Fluid Intake & Output', 'Daily Water Intake'),
      MemoryItem('nutrition', 'Fluid Intake & Output', 'Urination Frequency'),
      MemoryItem('nutrition', 'Vices & Risk Screening', 'Smoking / Vaping'),
      MemoryItem('nutrition', 'Vices & Risk Screening', 'Alcohol Drinking'),
      MemoryItem(
        'nutrition',
        'Vices & Risk Screening',
        'Coffee/ Caffeine',
        label: 'Coffee / Caffeine',
      ),
      MemoryItem('nutrition', 'Vices & Risk Screening', 'Lack of Exercise'),
      // "Poor Sleep / Staying Up Late" is one card in the PDF.
      MemoryItem('nutrition', 'Vices & Risk Screening', 'Poor Sleep'),
      MemoryItem('nutrition', 'Vices & Risk Screening', 'High Stress Levels'),
    ],
  ),
  (
    'Procedures & Advice',
    [
      MemoryItem(
        'procedures',
        'Pre-Measurement Instructions (BP Taking)',
        'Rest for 5 minutes',
        label: 'Rest',
      ),
      MemoryItem(
        'procedures',
        'Pre-Measurement Instructions (BP Taking)',
        'Bare the arm / Roll up sleeve',
      ),
      MemoryItem('procedures', 'Medical Procedures', 'Blood Test'),
      MemoryItem('procedures', 'Medical Procedures', 'ECG'),
      MemoryItem(
        'procedures',
        'Hypertension Prevention & Nursing Advice',
        'Eat Healthy Foods',
      ),
      MemoryItem(
        'procedures',
        'Hypertension Prevention & Nursing Advice',
        'Avoid drinking too much alcohol.',
        label: 'Limit Alcohol',
      ),
      MemoryItem(
        'procedures',
        'Hypertension Prevention & Nursing Advice',
        'Weight Control / Healthy Weight',
        label: 'Healthy Weight',
      ),
      MemoryItem(
        'procedures',
        'Hypertension Prevention & Nursing Advice',
        'Get Enough Sleep (7–8 Hours)',
      ),
      MemoryItem(
        'procedures',
        'Hypertension Prevention & Nursing Advice',
        'Regular Medical Checkup',
      ),
      MemoryItem(
        'procedures',
        'Hypertension Prevention & Nursing Advice',
        'Take your medicine on time.',
        label: 'Take Medicine on Time',
      ),
    ],
  ),
];

/// Looks the level specs up in the lesson content. A pair whose sign is
/// missing or has no recording is dropped, and a level left with fewer than
/// two pairs is dropped with it.
List<MemoryLevel> resolveMemoryLevels(
  List<SignEntry> signs, {
  List<(String, List<MemoryItem>)> specs = memoryLevelSpecs,
}) {
  final byKey = {for (final e in signs) e.sign.key: e.sign};
  final levels = <MemoryLevel>[];
  for (final (title, items) in specs) {
    final pairs = [
      for (final item in items)
        if (byKey[item.key] case final sign? when sign.media != null)
          MemoryPair(sign: sign, label: item.label ?? sign.term),
    ];
    if (pairs.length >= 2) {
      levels.add(
        MemoryLevel(number: levels.length + 1, title: title, pairs: pairs),
      );
    }
  }
  return levels;
}

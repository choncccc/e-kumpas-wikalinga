import 'package:flutter/foundation.dart';

import '../../data/user_profile.dart';

/// Answers gathered so far during sign-up, plus their validation rules.
class OnboardingDraft extends ChangeNotifier {
  OnboardingDraft({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const minAge = 3;
  static const maxAge = 120;
  static const nameMax = 60;
  static const nicknameMax = 20;

  String _name = '';
  String _nickname = '';
  DateTime? _birthdate;
  String? _photoPath;

  String get name => _name;
  String get nickname => _nickname;
  DateTime? get birthdate => _birthdate;

  /// Always derived from the birthday; never entered by hand.
  int? get age => ageFromBirthdate;

  /// Temporary picker path; copied into app storage when the profile is saved.
  String? get photoPath => _photoPath;

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Age implied by the chosen birthdate, if one has been picked.
  int? get ageFromBirthdate =>
      _birthdate == null ? null : UserProfile.ageOn(_birthdate!, today);

  set name(String v) => _update(() => _name = v);
  set nickname(String v) => _update(() => _nickname = v);
  set photoPath(String? v) => _update(() => _photoPath = v);

  set birthdate(DateTime? v) => _update(() => _birthdate = v);

  void _update(VoidCallback change) {
    change();
    notifyListeners();
  }

  // ---- Validation (null means valid) ----

  static final _nameChars = RegExp(r"^[\p{L}\p{M} .'\-]+$", unicode: true);

  String? get nameError {
    final v = _name.trim();
    if (v.isEmpty) return '';
    if (v.length < 2) return 'Your name needs at least 2 letters.';
    if (!_nameChars.hasMatch(v)) {
      return 'Use letters only (spaces, dots, dashes and apostrophes are okay).';
    }
    return null;
  }

  String? get nicknameError {
    final v = _nickname.trim();
    if (v.isEmpty) return '';
    if (v.length > nicknameMax) {
      return 'Keep it to $nicknameMax characters or fewer.';
    }
    return null;
  }

  String? get birthdateError {
    final b = _birthdate;
    if (b == null) return '';
    if (b.isAfter(today)) return 'Your birthday can’t be in the future.';
    final a = ageFromBirthdate!;
    if (a < minAge) return 'You need to be at least $minAge years old.';
    if (a > maxAge) return 'Please double-check the year.';
    return null;
  }

  /// First word of the full name, used as a nickname suggestion.
  String get suggestedNickname {
    final first = _name.trim().split(RegExp(r'\s+')).first;
    return first.length > nicknameMax ? first.substring(0, nicknameMax) : first;
  }

  UserProfile toProfile() => UserProfile(
    name: _name.trim(),
    nickname: _nickname.trim(),
    birthdate: _birthdate!,
    age: age!,
    createdAt: _clock(),
    photoPath: _photoPath,
  );
}

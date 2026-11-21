/// The learner's profile, collected during onboarding. One row per device.
class UserProfile {
  const UserProfile({
    this.id,
    required this.name,
    required this.nickname,
    required this.birthdate,
    required this.age,
    required this.createdAt,
    this.photoPath,
  });

  final int? id;
  final String name;
  final String nickname;
  final DateTime birthdate;

  /// Age as entered during sign-up. Use [currentAge] for display, since a
  /// stored age goes stale after the next birthday.
  final int age;
  final DateTime createdAt;

  /// Absolute path to the profile picture in app storage, if one was added.
  final String? photoPath;

  int get currentAge => ageOn(birthdate, DateTime.now());

  /// Whole years between [birthdate] and [today].
  static int ageOn(DateTime birthdate, DateTime today) {
    var years = today.year - birthdate.year;
    final hadBirthday =
        today.month > birthdate.month ||
        (today.month == birthdate.month && today.day >= birthdate.day);
    if (!hadBirthday) years--;
    return years;
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'nickname': nickname,
    'birthdate': _isoDate(birthdate),
    'age': age,
    'created_at': createdAt.toIso8601String(),
    'photo_path': photoPath,
  };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
    id: map['id'] as int?,
    name: map['name'] as String,
    nickname: map['nickname'] as String,
    birthdate: DateTime.parse(map['birthdate'] as String),
    age: map['age'] as int,
    createdAt: DateTime.parse(map['created_at'] as String),
    photoPath: map['photo_path'] as String?,
  );

  UserProfile copyWith({
    String? name,
    String? nickname,
    DateTime? birthdate,
    int? age,
    String? photoPath,
    bool clearPhoto = false,
  }) => UserProfile(
    id: id,
    name: name ?? this.name,
    nickname: nickname ?? this.nickname,
    birthdate: birthdate ?? this.birthdate,
    age: age ?? this.age,
    createdAt: createdAt,
    photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
  );

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

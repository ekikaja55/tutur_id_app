enum UserStatus {
  all,
  active,
  suspended;

  String toMap() => name;

  static UserStatus fromMap(String? value) {
    if (value == null) return UserStatus.active;
    return UserStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserStatus.active,
    );
  }
}

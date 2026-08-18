enum UserRole {
  student,
  admin;

  String toMap() => name;
  static UserRole fromMap(String? value) {
    if (value == null) return UserRole.student;
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.student,
    );
  }
}

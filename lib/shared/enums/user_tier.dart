enum UserTier {
  starter,
  growth,
  ultimate;

  String toMap() => name;

  static UserTier fromMap(String? value) {
    if (value == null) return UserTier.starter;
    return UserTier.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserTier.starter,
    );
  }
}

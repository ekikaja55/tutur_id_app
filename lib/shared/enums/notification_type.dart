enum NotificationType {
  system,
  gamification,
  transaction,
  reportResponse;

  String toMap() => name;
  static NotificationType fromMap(String? value) {
    if (value == null) return NotificationType.system;

    return NotificationType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => NotificationType.system,
    );
  }
}

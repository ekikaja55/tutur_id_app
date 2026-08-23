enum ReportCategory {
  aiCamera,
  payment,
  material;

  String toMap() => name;
  static ReportCategory fromMap(String? value) {
    if (value == null) return ReportCategory.aiCamera;
    return ReportCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ReportCategory.aiCamera,
    );
  }
}

enum ReportStatus {
  accepted,
  onProcess,
  completed;

  String toMap() => name;
  static ReportStatus fromMap(String? value) {
    if (value == null) return ReportStatus.accepted;
    return ReportStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ReportStatus.accepted,
    );
  }
}

class LevelModel {
  final int level;
  final String title;
  final String description;

  const LevelModel({
    required this.level,
    required this.title,
    required this.description,
  });

  // karena fix 3 level
  static const List<LevelModel> all = [
    LevelModel(
      level: 1,
      title: 'First Steps',
      description: 'Langkah awal mengenal fingerspelling dan angka dasar',
    ),
    LevelModel(
      level: 2,
      title: 'Essential Skills',
      description: 'Melengkapi kemampuan mengeja secara utuh',
    ),
    LevelModel(
      level: 3,
      title: 'Daily Conversation',
      description: 'Belajar kosakata percakapan sehari-hari',
    ),
  ];
}

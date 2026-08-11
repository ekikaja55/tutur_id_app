class MaterialItem {
  final String id;
  final String label;
  final String videoUrl;
  final String? imageUrl;

  MaterialItem({
    required this.id,
    required this.label,
    required this.videoUrl,
    this.imageUrl,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'] as String,
      label: json['label'] as String,
      videoUrl: json['videoUrl'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
    };
  }
}

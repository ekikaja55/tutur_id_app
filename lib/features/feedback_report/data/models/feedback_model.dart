// model buat nampung feedback user
class FeedbackModel {
  final String id;
  final String userId;
  final int rating;
  final String description;
  final String? adminResponse;
  final DateTime createdAt;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.rating,
    required this.description,
    this.adminResponse,
    required this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      rating: json['rating'] as int,
      description: json['description'] as String,
      adminResponse: json['adminResponse'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'rating': rating,
      'description': description,
      'adminResponse': adminResponse,
      'createdAt': createdAt,
    };
  }
}

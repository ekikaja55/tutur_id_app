class LeaderboardEntryModel {
  final String userId;
  final String username;
  final String? photoUrl;
  final int weeklyXp;
  final String subscriptionTier;

  LeaderboardEntryModel({
    required this.userId,
    required this.username,
    this.photoUrl,
    required this.weeklyXp,
    required this.subscriptionTier,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      userId: json['userId'] as String,
      username: json['username'] as String,
      photoUrl: json['photoUrl'] as String?,
      weeklyXp: json['weeklyXp'] as int? ?? 0,
      subscriptionTier: json['subscriptionTier'] as String? ?? 'starter',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'photoUrl': photoUrl,
      'weeklyXp': weeklyXp,
      'subscriptionTier': subscriptionTier,
    };
  }
}

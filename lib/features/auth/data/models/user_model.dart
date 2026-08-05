import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';

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

class UserModel {
  final String uid;
  final String email;
  final String? username;
  final String? phoneNumber;
  final String? photoUrl;
  final UserRole role;
  final int battery;
  final UserTier subscriptionTier;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.username,
    this.phoneNumber,
    this.photoUrl,
    this.role = UserRole.student,
    this.battery = 14,
    this.subscriptionTier = UserTier.starter,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      role: UserRole.fromMap(json['role'] as String?),
      battery: json['battery'] as int? ?? 14,
      subscriptionTier: UserTier.fromMap(json['subscriptionTier'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'role': role,
      'battery': battery,
      'subscriptionTier': subscriptionTier,
      'createdAt': createdAt,
    };
  }

  UserModel copyWith({
    String? username,
    String? phoneNumber,
    String? photoUrl,
    UserRole? role,
    int? battery,
    UserTier? subscriptionTier,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      battery: battery ?? this.battery,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt,
    );
  }
}

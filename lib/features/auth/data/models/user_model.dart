import 'package:tutur_id_app/shared/enums/user_role.dart';
import 'package:tutur_id_app/shared/enums/user_tier.dart';

class UserModel {
  final String uid; 
  final String email;
  final String? username;
  final String? phoneNumber;
  final String? photoUrl;
  final UserRole role;

  final int battery;
  final DateTime? batteryLastRefill;

  final UserTier subscriptionTier;
  final DateTime? subscriptionExpiresAt;

  final int xp;
  final int streak;
  final DateTime? lastLoginDate;

  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.username,
    this.phoneNumber,
    this.photoUrl,
    this.role = UserRole.student,
    this.battery = 14,
    this.batteryLastRefill,
    this.subscriptionTier = UserTier.starter,
    this.subscriptionExpiresAt,
    this.xp = 0,
    this.streak = 0,
    this.lastLoginDate,
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
      batteryLastRefill: json['batteryLastRefill'] != null
          ? DateTime.parse(json['batteryLastRefill'] as String)
          : null,
      subscriptionTier: UserTier.fromMap(json['subscriptionTier'] as String?),
      subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
          ? DateTime.parse(json['subscriptionTier'] as String)
          : null,
      xp: json['xp'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      lastLoginDate: json['lastLoginDate'] != null
          ? DateTime.parse(json['lastLoginDate'] as String)
          : null,
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
      'batteryLastRefill': batteryLastRefill,
      'subscriptionTier': subscriptionTier,
      'subscriptionExpiresAt': subscriptionExpiresAt,
      'xp': xp,
      'streak': streak,
      'lastLoginDate': lastLoginDate,
      'createdAt': createdAt,
    };
  }

  UserModel copyWith({
    String? username,
    String? phoneNumber,
    String? photoUrl,
    UserRole? role,
    int? battery,
    DateTime? batteryLastRefill,
    UserTier? subscriptionTier,
    DateTime? subscriptionExpiresAt,
    int? xp,
    int? streak,
    DateTime? lastLoginDate,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      battery: battery ?? this.battery,
      batteryLastRefill: batteryLastRefill,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiresAt: subscriptionExpiresAt,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      createdAt: createdAt,
    );
  }
}

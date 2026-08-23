import 'package:tutur_id_app/shared/enums/transaction_status.dart';
import 'package:tutur_id_app/shared/enums/user_tier.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String orderId;
  final UserTier tier;
  final int grossAmount;
  final TransactionStatus status;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.tier,
    required this.grossAmount,
    this.status = TransactionStatus.pending,
    this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      orderId: json['orderId'] as String,
      tier: UserTier.fromMap(json['tier'] as String?),
      grossAmount: json['grossAmount'] as int,
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      paymentMethod: json['paymentMethod'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'orderId': orderId,
      'tier': tier.toMap(),
      'grossAmount': grossAmount,
      'status': status.name,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

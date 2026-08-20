import 'package:tutur_id_app/shared/enums/xp_source.dart';

class XpLogModel {
  final String id;
  final String userId;
  final int amount;
  final XpSource source;
  final String? referenceId;
  final DateTime createdAt;

  XpLogModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.source,

    this.referenceId,
    required this.createdAt,
  });

  factory XpLogModel.fromJson(Map<String, dynamic> json) {
    return XpLogModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      amount: json['amount'] as int,
      source: XpSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => XpSource.quiz,
      ),
      referenceId: json['referenceId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'source': source.name,
      'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

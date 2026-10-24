import '../core/utils/date_utils.dart';

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromUsername,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String fromUsername;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id']?.toString() ?? '',
    fromUid: json['fromUid']?.toString() ?? '',
    toUid: json['toUid']?.toString() ?? '',
    fromUsername: json['fromUsername']?.toString() ?? 'لاعب',
    status: json['status']?.toString() ?? 'pending',
    createdAt: ChallengeDateUtils.parse(json['createdAt']),
    updatedAt: ChallengeDateUtils.parse(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromUid': fromUid,
    'toUid': toUid,
    'fromUsername': fromUsername,
    'status': status,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  FriendRequest copyWith({
    String? id,
    String? fromUid,
    String? toUid,
    String? fromUsername,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      fromUid: fromUid ?? this.fromUid,
      toUid: toUid ?? this.toUid,
      fromUsername: fromUsername ?? this.fromUsername,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

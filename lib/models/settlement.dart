import 'package:uuid/uuid.dart';

/// Settlement model - represents a payment between two members
class Settlement {
  final String id;
  final String groupId;
  final String payerId; // Member ID of person who paid
  final String payeeId; // Member ID of person who received payment
  final double amount;
  final String currency;
  final DateTime date;
  final String? note;
  final int createdAt;
  final String deviceId; // Which device created this settlement

  Settlement({
    String? id,
    required this.groupId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.currency,
    DateTime? date,
    this.note,
    int? createdAt,
    required this.deviceId,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'payerId': payerId,
      'payeeId': payeeId,
      'amount': amount,
      'currency': currency,
      'date': date.toIso8601String(),
      'note': note,
      'createdAt': createdAt,
      'deviceId': deviceId,
    };
  }

  /// Create from database Map
  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      payerId: map['payerId'] as String,
      payeeId: map['payeeId'] as String,
      amount: map['amount'] as double,
      currency: map['currency'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: map['createdAt'] as int,
      deviceId: map['deviceId'] as String,
    );
  }

  /// Convert to JSON for export/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'payerId': payerId,
      'payeeId': payeeId,
      'amount': amount,
      'currency': currency,
      'date': date.toIso8601String(),
      'note': note,
      'createdAt': createdAt,
      'deviceId': deviceId,
    };
  }

  /// Create from JSON
  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      payerId: json['payerId'] as String,
      payeeId: json['payeeId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      createdAt: json['createdAt'] as int,
      deviceId: json['deviceId'] as String,
    );
  }

  /// Create a copy with updated fields
  Settlement copyWith({
    String? id,
    String? groupId,
    String? payerId,
    String? payeeId,
    double? amount,
    String? currency,
    DateTime? date,
    String? note,
    int? createdAt,
    String? deviceId,
  }) {
    return Settlement(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      payerId: payerId ?? this.payerId,
      payeeId: payeeId ?? this.payeeId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  String toString() {
    return 'Settlement(id: $id, amount: $amount $currency, from: $payerId, to: $payeeId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Settlement &&
        other.id == id &&
        other.groupId == groupId &&
        other.payerId == payerId &&
        other.payeeId == payeeId &&
        other.amount == amount &&
        other.currency == currency &&
        other.date == date &&
        other.note == note &&
        other.createdAt == createdAt &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        groupId.hashCode ^
        payerId.hashCode ^
        payeeId.hashCode ^
        amount.hashCode ^
        currency.hashCode ^
        date.hashCode ^
        note.hashCode ^
        createdAt.hashCode ^
        deviceId.hashCode;
  }
}

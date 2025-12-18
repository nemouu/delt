import 'dart:convert';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:uuid/uuid.dart';
import 'enums.dart';

/// Group expense model - represents an expense in a shared group
class GroupExpense {
  final String id;
  final String groupId;
  final double amount;
  final String currency;
  final String category;
  final DateTime date;
  final String? note;
  final String paidBy; // Member ID
  final List<String> splitBetween; // List of Member IDs
  final SplitType splitType;
  final Map<String, double>? splitDetails; // For UNEQUAL split
  final int createdAt;
  final int updatedAt;
  final String deviceId; // Which device created this
  final bool isSettled; // Optional: Mark as paid back

  GroupExpense({
    String? id,
    required this.groupId,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    this.note,
    required this.paidBy,
    required this.splitBetween,
    SplitType? splitType,
    this.splitDetails,
    int? createdAt,
    int? updatedAt,
    required this.deviceId,
    bool? isSettled,
  })  : id = id ?? const Uuid().v4(),
        splitType = splitType ?? SplitType.equal,
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        isSettled = isSettled ?? false;

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'amount': amount,
      'currency': currency,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'paidBy': paidBy,
      'splitBetween': jsonEncode(splitBetween),
      'splitType': splitType.toStr(),
      'splitDetails': splitDetails != null ? jsonEncode(splitDetails) : null,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deviceId': deviceId,
      'isSettled': isSettled ? 1 : 0,
    };
  }

  /// Create from database Map
  factory GroupExpense.fromMap(Map<String, dynamic> map) {
    return GroupExpense(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      amount: map['amount'] as double,
      currency: map['currency'] as String,
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      paidBy: map['paidBy'] as String,
      splitBetween: (jsonDecode(map['splitBetween'] as String) as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      splitType: SplitTypeExtension.fromStr(map['splitType'] as String),
      splitDetails: map['splitDetails'] != null
          ? (jsonDecode(map['splitDetails'] as String) as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toDouble()))
          : null,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      deviceId: map['deviceId'] as String,
      isSettled: (map['isSettled'] as int) == 1,
    );
  }

  /// Convert to JSON for export/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'amount': amount,
      'currency': currency,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'paidBy': paidBy,
      'splitBetween': splitBetween,
      'splitType': splitType.toStr(),
      'splitDetails': splitDetails,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deviceId': deviceId,
      'isSettled': isSettled,
    };
  }

  /// Create from JSON
  factory GroupExpense.fromJson(Map<String, dynamic> json) {
    return GroupExpense(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      paidBy: json['paidBy'] as String,
      splitBetween: (json['splitBetween'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      splitType: SplitTypeExtension.fromStr(json['splitType'] as String),
      splitDetails: json['splitDetails'] != null
          ? (json['splitDetails'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toDouble()))
          : null,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      deviceId: json['deviceId'] as String,
      isSettled: json['isSettled'] as bool,
    );
  }

  /// Create a copy with updated fields
  GroupExpense copyWith({
    String? id,
    String? groupId,
    double? amount,
    String? currency,
    String? category,
    DateTime? date,
    String? note,
    String? paidBy,
    List<String>? splitBetween,
    SplitType? splitType,
    Map<String, double>? splitDetails,
    int? createdAt,
    int? updatedAt,
    String? deviceId,
    bool? isSettled,
  }) {
    return GroupExpense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      paidBy: paidBy ?? this.paidBy,
      splitBetween: splitBetween ?? this.splitBetween,
      splitType: splitType ?? this.splitType,
      splitDetails: splitDetails ?? this.splitDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  @override
  String toString() {
    return 'GroupExpense(id: $id, amount: $amount $currency, category: $category, paidBy: $paidBy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GroupExpense &&
        other.id == id &&
        other.groupId == groupId &&
        other.amount == amount &&
        other.currency == currency &&
        other.category == category &&
        other.date == date &&
        other.note == note &&
        other.paidBy == paidBy &&
        listEquals(other.splitBetween, splitBetween) &&
        other.splitType == splitType &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deviceId == deviceId &&
        other.isSettled == isSettled;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        groupId.hashCode ^
        amount.hashCode ^
        currency.hashCode ^
        category.hashCode ^
        date.hashCode ^
        note.hashCode ^
        paidBy.hashCode ^
        splitBetween.hashCode ^
        splitType.hashCode ^
        splitDetails.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        deviceId.hashCode ^
        isSettled.hashCode;
  }
}

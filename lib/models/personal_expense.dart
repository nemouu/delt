import 'package:uuid/uuid.dart';

/// Personal expense model
class PersonalExpense {
  final String id;
  final double amount;
  final String currency; // ISO 4217 code (EUR, NOK, USD)
  final String category;
  final DateTime date;
  final String? note;
  final String? groupExpenseId; // Link to source group expense if synced from group
  final int createdAt;
  final int updatedAt;

  PersonalExpense({
    String? id,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    this.note,
    this.groupExpenseId,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'category': category,
      'date': date.toIso8601String(), // Store as ISO8601 string
      'note': note,
      'groupExpenseId': groupExpenseId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from database Map
  factory PersonalExpense.fromMap(Map<String, dynamic> map) {
    return PersonalExpense(
      id: map['id'] as String,
      amount: map['amount'] as double,
      currency: map['currency'] as String,
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      groupExpenseId: map['groupExpenseId'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }

  /// Convert to JSON for export/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'groupExpenseId': groupExpenseId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from JSON
  factory PersonalExpense.fromJson(Map<String, dynamic> json) {
    return PersonalExpense(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      groupExpenseId: json['groupExpenseId'] as String?,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }

  /// Create a copy with updated fields
  PersonalExpense copyWith({
    String? id,
    double? amount,
    String? currency,
    String? category,
    DateTime? date,
    String? note,
    String? groupExpenseId,
    int? createdAt,
    int? updatedAt,
  }) {
    return PersonalExpense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      groupExpenseId: groupExpenseId ?? this.groupExpenseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PersonalExpense(id: $id, amount: $amount $currency, category: $category, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PersonalExpense &&
        other.id == id &&
        other.amount == amount &&
        other.currency == currency &&
        other.category == category &&
        other.date == date &&
        other.note == note &&
        other.groupExpenseId == groupExpenseId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        amount.hashCode ^
        currency.hashCode ^
        category.hashCode ^
        date.hashCode ^
        note.hashCode ^
        groupExpenseId.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:uuid/uuid.dart';

/// User model - represents the app user
class User {
  final String id;
  final String username;
  final List<String> currencies;
  final String defaultCurrency; // Default currency for expenses
  final int createdAt;
  final int updatedAt;

  User({
    String? id,
    required this.username,
    List<String>? currencies,
    String? defaultCurrency,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        currencies = currencies ?? ['EUR', 'USD', 'GBP', 'DKK', 'SEK', 'NOK'],
        defaultCurrency = defaultCurrency ?? (currencies?.isNotEmpty == true ? currencies!.first : 'EUR'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'currencies': jsonEncode(currencies),
      'defaultCurrency': defaultCurrency,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from database Map
  factory User.fromMap(Map<String, dynamic> map) {
    final currencies = (jsonDecode(map['currencies'] as String) as List<dynamic>)
        .map((e) => e as String)
        .toList();
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      currencies: currencies,
      defaultCurrency: map['defaultCurrency'] as String? ?? currencies.first,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }

  /// Convert to JSON for export/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'currencies': currencies,
      'defaultCurrency': defaultCurrency,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    final currencies = (json['currencies'] as List<dynamic>)
        .map((e) => e as String)
        .toList();
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      currencies: currencies,
      defaultCurrency: json['defaultCurrency'] as String? ?? currencies.first,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }

  /// Create a copy with updated fields
  User copyWith({
    String? id,
    String? username,
    List<String>? currencies,
    String? defaultCurrency,
    int? createdAt,
    int? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      currencies: currencies ?? this.currencies,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, currencies: $currencies)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is User &&
        other.id == id &&
        other.username == username &&
        listEquals(other.currencies, currencies) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        username.hashCode ^
        currencies.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

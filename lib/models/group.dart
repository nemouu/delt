import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:uuid/uuid.dart';
import 'enums.dart';

/// Group model - represents a shared expense group
class Group {
  final String id;
  final String name;
  final Uint8List secretKey; // For authentication
  final String createdBy; // Member ID of creator
  final List<String> currencies; // Currencies used in this group
  final String defaultCurrency; // Default currency for this group
  final bool isPersonal; // True for the user's personal expense group

  // Sharing state
  final ShareState shareState; // Tracks actual sharing status
  final bool isSharedAcrossDevices; // UI flag - shows sync options
  final List<String> knownDeviceIds; // Device IDs that have joined

  // Sync configuration
  final SyncMethod syncMethod;

  // Timestamps
  final int createdAt;
  final int updatedAt;
  final int? lastSyncedAt;
  final int? lastQRGeneratedAt; // When QR code was last generated

  Group({
    String? id,
    required this.name,
    required this.secretKey,
    required this.createdBy,
    List<String>? currencies,
    String? defaultCurrency,
    bool? isPersonal,
    ShareState? shareState,
    bool? isSharedAcrossDevices,
    List<String>? knownDeviceIds,
    SyncMethod? syncMethod,
    int? createdAt,
    int? updatedAt,
    this.lastSyncedAt,
    this.lastQRGeneratedAt,
  })  : id = id ?? const Uuid().v4(),
        currencies = currencies ?? [],
        defaultCurrency = defaultCurrency ?? (currencies?.isNotEmpty == true ? currencies!.first : 'EUR'),
        isPersonal = isPersonal ?? false,
        shareState = shareState ?? ShareState.local,
        isSharedAcrossDevices = isSharedAcrossDevices ?? false,
        knownDeviceIds = knownDeviceIds ?? [],
        syncMethod = syncMethod ?? SyncMethod.manual,
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Computed property: device count
  int get deviceCount => knownDeviceIds.length;

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'secretKey': secretKey, // Store as BLOB
      'createdBy': createdBy,
      'currencies': jsonEncode(currencies),
      'defaultCurrency': defaultCurrency,
      'isPersonal': isPersonal ? 1 : 0,
      'shareState': shareState.toStr(),
      'isSharedAcrossDevices': isSharedAcrossDevices ? 1 : 0,
      'knownDeviceIds': jsonEncode(knownDeviceIds),
      'syncMethod': syncMethod.toStr(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastSyncedAt': lastSyncedAt,
      'lastQRGeneratedAt': lastQRGeneratedAt,
    };
  }

  /// Create from database Map
  factory Group.fromMap(Map<String, dynamic> map) {
    final currencies = (jsonDecode(map['currencies'] as String) as List<dynamic>)
        .map((e) => e as String)
        .toList();
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      secretKey: map['secretKey'] as Uint8List,
      createdBy: map['createdBy'] as String,
      currencies: currencies,
      defaultCurrency: map['defaultCurrency'] as String? ?? (currencies.isNotEmpty ? currencies.first : 'EUR'),
      isPersonal: (map['isPersonal'] as int) == 1,
      shareState: ShareStateExtension.fromStr(map['shareState'] as String),
      isSharedAcrossDevices: (map['isSharedAcrossDevices'] as int) == 1,
      knownDeviceIds:
          (jsonDecode(map['knownDeviceIds'] as String) as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      syncMethod: SyncMethodExtension.fromStr(map['syncMethod'] as String),
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      lastSyncedAt: map['lastSyncedAt'] as int?,
      lastQRGeneratedAt: map['lastQRGeneratedAt'] as int?,
    );
  }

  /// Convert to JSON for export/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'secretKey': base64Encode(secretKey), // Encode as base64 for JSON
      'createdBy': createdBy,
      'currencies': currencies,
      'defaultCurrency': defaultCurrency,
      'isPersonal': isPersonal,
      'shareState': shareState.toStr(),
      'isSharedAcrossDevices': isSharedAcrossDevices,
      'knownDeviceIds': knownDeviceIds,
      'syncMethod': syncMethod.toStr(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastSyncedAt': lastSyncedAt,
      'lastQRGeneratedAt': lastQRGeneratedAt,
    };
  }

  /// Create from JSON
  factory Group.fromJson(Map<String, dynamic> json) {
    final currencies = (json['currencies'] as List<dynamic>)
        .map((e) => e as String)
        .toList();
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      secretKey: base64Decode(json['secretKey'] as String),
      createdBy: json['createdBy'] as String,
      currencies: currencies,
      defaultCurrency: json['defaultCurrency'] as String? ?? (currencies.isNotEmpty ? currencies.first : 'EUR'),
      isPersonal: json['isPersonal'] as bool,
      shareState: ShareStateExtension.fromStr(json['shareState'] as String),
      isSharedAcrossDevices: json['isSharedAcrossDevices'] as bool,
      knownDeviceIds: (json['knownDeviceIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      syncMethod: SyncMethodExtension.fromStr(json['syncMethod'] as String),
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      lastSyncedAt: json['lastSyncedAt'] as int?,
      lastQRGeneratedAt: json['lastQRGeneratedAt'] as int?,
    );
  }

  /// Create a copy with updated fields
  Group copyWith({
    String? id,
    String? name,
    Uint8List? secretKey,
    String? createdBy,
    List<String>? currencies,
    String? defaultCurrency,
    bool? isPersonal,
    ShareState? shareState,
    bool? isSharedAcrossDevices,
    List<String>? knownDeviceIds,
    SyncMethod? syncMethod,
    int? createdAt,
    int? updatedAt,
    int? lastSyncedAt,
    int? lastQRGeneratedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      secretKey: secretKey ?? this.secretKey,
      createdBy: createdBy ?? this.createdBy,
      currencies: currencies ?? this.currencies,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      isPersonal: isPersonal ?? this.isPersonal,
      shareState: shareState ?? this.shareState,
      isSharedAcrossDevices:
          isSharedAcrossDevices ?? this.isSharedAcrossDevices,
      knownDeviceIds: knownDeviceIds ?? this.knownDeviceIds,
      syncMethod: syncMethod ?? this.syncMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastQRGeneratedAt: lastQRGeneratedAt ?? this.lastQRGeneratedAt,
    );
  }

  @override
  String toString() {
    return 'Group(id: $id, name: $name, shareState: $shareState, deviceCount: $deviceCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Group &&
        other.id == id &&
        other.name == name &&
        listEquals(other.secretKey, secretKey) &&
        other.createdBy == createdBy &&
        listEquals(other.currencies, currencies) &&
        other.isPersonal == isPersonal &&
        other.shareState == shareState &&
        other.isSharedAcrossDevices == isSharedAcrossDevices &&
        listEquals(other.knownDeviceIds, knownDeviceIds) &&
        other.syncMethod == syncMethod &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.lastSyncedAt == lastSyncedAt &&
        other.lastQRGeneratedAt == lastQRGeneratedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        secretKey.hashCode ^
        createdBy.hashCode ^
        currencies.hashCode ^
        isPersonal.hashCode ^
        shareState.hashCode ^
        isSharedAcrossDevices.hashCode ^
        knownDeviceIds.hashCode ^
        syncMethod.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        lastSyncedAt.hashCode ^
        lastQRGeneratedAt.hashCode;
  }
}

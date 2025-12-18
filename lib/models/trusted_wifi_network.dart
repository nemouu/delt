import 'package:uuid/uuid.dart';
import 'enums.dart';

/// Trusted WiFi network model - represents a network where auto-sync is allowed
class TrustedWifiNetwork {
  final String id;
  final String ssid; // Network name (e.g., "Villa Rosa WiFi")
  final String? bssid; // Optional MAC address for more specific matching
  final String displayName; // User-friendly name
  final NetworkType networkType; // PERSONAL or GROUP_SPECIFIC
  final String? linkedGroupId; // null for personal networks, group ID for group networks
  final int addedAt;
  final int updatedAt;

  TrustedWifiNetwork({
    String? id,
    required this.ssid,
    this.bssid,
    required this.displayName,
    required this.networkType,
    this.linkedGroupId,
    int? addedAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        addedAt = addedAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ssid': ssid,
      'bssid': bssid,
      'displayName': displayName,
      'networkType': networkType.toStr(),
      'linkedGroupId': linkedGroupId,
      'addedAt': addedAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from database Map
  factory TrustedWifiNetwork.fromMap(Map<String, dynamic> map) {
    return TrustedWifiNetwork(
      id: map['id'] as String,
      ssid: map['ssid'] as String,
      bssid: map['bssid'] as String?,
      displayName: map['displayName'] as String,
      networkType: NetworkTypeExtension.fromStr(map['networkType'] as String),
      linkedGroupId: map['linkedGroupId'] as String?,
      addedAt: map['addedAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }

  /// Convert to JSON for export/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ssid': ssid,
      'bssid': bssid,
      'displayName': displayName,
      'networkType': networkType.toStr(),
      'linkedGroupId': linkedGroupId,
      'addedAt': addedAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from JSON
  factory TrustedWifiNetwork.fromJson(Map<String, dynamic> json) {
    return TrustedWifiNetwork(
      id: json['id'] as String,
      ssid: json['ssid'] as String,
      bssid: json['bssid'] as String?,
      displayName: json['displayName'] as String,
      networkType: NetworkTypeExtension.fromStr(json['networkType'] as String),
      linkedGroupId: json['linkedGroupId'] as String?,
      addedAt: json['addedAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }

  /// Create a copy with updated fields
  TrustedWifiNetwork copyWith({
    String? id,
    String? ssid,
    String? bssid,
    String? displayName,
    NetworkType? networkType,
    String? linkedGroupId,
    int? addedAt,
    int? updatedAt,
  }) {
    return TrustedWifiNetwork(
      id: id ?? this.id,
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      displayName: displayName ?? this.displayName,
      networkType: networkType ?? this.networkType,
      linkedGroupId: linkedGroupId ?? this.linkedGroupId,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TrustedWifiNetwork(id: $id, ssid: $ssid, type: $networkType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TrustedWifiNetwork &&
        other.id == id &&
        other.ssid == ssid &&
        other.bssid == bssid &&
        other.displayName == displayName &&
        other.networkType == networkType &&
        other.linkedGroupId == linkedGroupId &&
        other.addedAt == addedAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        ssid.hashCode ^
        bssid.hashCode ^
        displayName.hashCode ^
        networkType.hashCode ^
        linkedGroupId.hashCode ^
        addedAt.hashCode ^
        updatedAt.hashCode;
  }
}

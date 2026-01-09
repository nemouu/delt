import 'dart:convert';
import 'dart:typed_data';

/// Message types for sync protocol
enum MessageType {
  handshake, // Initial connection request
  challenge, // Server sends auth challenge
  response, // Client responds to challenge
  dataRequest, // Request for group data
  dataResponse, // Send group data
  ack, // Acknowledgement of successful sync
  error, // Error occurred
}

/// Sync message for communication between devices
class SyncMessage {
  final MessageType type;
  final String? groupId; // Group being synced
  final String? deviceId; // Sender's device ID
  final Map<String, dynamic>? payload; // Message payload
  final String? error; // Error message (if type is ERROR)
  final int timestamp; // Message timestamp

  SyncMessage({
    required this.type,
    this.groupId,
    this.deviceId,
    this.payload,
    this.error,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert to JSON for network transmission
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'groupId': groupId,
      'deviceId': deviceId,
      'payload': payload,
      'error': error,
      'timestamp': timestamp,
    };
  }

  /// Create from JSON
  factory SyncMessage.fromJson(Map<String, dynamic> json) {
    return SyncMessage(
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.error,
      ),
      groupId: json['groupId'] as String?,
      deviceId: json['deviceId'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      timestamp: json['timestamp'] as int,
    );
  }

  /// Serialize to bytes for network transmission
  Uint8List toBytes() {
    final jsonStr = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  /// Deserialize from bytes
  factory SyncMessage.fromBytes(Uint8List bytes) {
    final jsonStr = utf8.decode(bytes);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SyncMessage.fromJson(json);
  }

  @override
  String toString() {
    return 'SyncMessage(type: $type, groupId: $groupId, deviceId: $deviceId, timestamp: $timestamp)';
  }

  /// Factory methods for common message types

  /// Create HANDSHAKE message
  static SyncMessage handshake({
    required String groupId,
    required String deviceId,
  }) {
    return SyncMessage(
      type: MessageType.handshake,
      groupId: groupId,
      deviceId: deviceId,
      payload: {
        'protocolVersion': '1.0',
      },
    );
  }

  /// Create CHALLENGE message
  static SyncMessage challenge({
    required String groupId,
    required String nonce,
  }) {
    return SyncMessage(
      type: MessageType.challenge,
      groupId: groupId,
      payload: {
        'nonce': nonce,
      },
    );
  }

  /// Create RESPONSE message with HMAC signature
  static SyncMessage response({
    required String groupId,
    required String deviceId,
    required String signature,
  }) {
    return SyncMessage(
      type: MessageType.response,
      groupId: groupId,
      deviceId: deviceId,
      payload: {
        'signature': signature,
      },
    );
  }

  /// Create DATA_REQUEST message
  static SyncMessage dataRequest({
    required String groupId,
    required String deviceId,
    int? lastSyncedAt,
  }) {
    return SyncMessage(
      type: MessageType.dataRequest,
      groupId: groupId,
      deviceId: deviceId,
      payload: {
        'lastSyncedAt': lastSyncedAt,
      },
    );
  }

  /// Create DATA_RESPONSE message with group data
  static SyncMessage dataResponse({
    required String groupId,
    required String deviceId,
    required Map<String, dynamic> groupData,
  }) {
    return SyncMessage(
      type: MessageType.dataResponse,
      groupId: groupId,
      deviceId: deviceId,
      payload: groupData,
    );
  }

  /// Create ACK message
  static SyncMessage ack({
    required String groupId,
    required String deviceId,
  }) {
    return SyncMessage(
      type: MessageType.ack,
      groupId: groupId,
      deviceId: deviceId,
      payload: {
        'success': true,
      },
    );
  }

  /// Create ERROR message
  static SyncMessage createError({
    String? groupId,
    String? deviceId,
    required String errorMessage,
  }) {
    return SyncMessage(
      type: MessageType.error,
      groupId: groupId,
      deviceId: deviceId,
      error: errorMessage,
    );
  }

  /// Getters for common payload fields

  String? get nonce => payload?['nonce'] as String?;
  String? get signature => payload?['signature'] as String?;
  int? get lastSyncedAt => payload?['lastSyncedAt'] as int?;
  Map<String, dynamic>? get groupData => payload;
  String? get protocolVersion => payload?['protocolVersion'] as String?;
  bool get success => payload?['success'] == true;
}

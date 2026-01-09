import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../models/group.dart';
import '../../models/member.dart';
import '../../models/group_expense.dart';
import '../../models/settlement.dart';
import '../../database/dao/group_dao.dart';
import '../../database/dao/member_dao.dart';
import '../../database/dao/group_expense_dao.dart';
import '../../database/dao/settlement_dao.dart';
import 'sync_message.dart';

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String? error;
  final int syncedExpenses;
  final int syncedMembers;
  final int syncedSettlements;
  final int timestamp;

  SyncResult({
    required this.success,
    this.error,
    this.syncedExpenses = 0,
    this.syncedMembers = 0,
    this.syncedSettlements = 0,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  @override
  String toString() {
    if (!success) {
      return 'SyncResult(success: false, error: $error)';
    }
    return 'SyncResult(success: true, expenses: $syncedExpenses, members: $syncedMembers, settlements: $syncedSettlements)';
  }
}

/// Sync protocol implementation with HMAC challenge-response authentication
class SyncProtocol {
  final _groupDao = GroupDao();
  final _memberDao = MemberDao();
  final _expenseDao = GroupExpenseDao();
  final _settlementDao = SettlementDao();
  final _random = Random.secure();

  /// Generate a random nonce for challenge-response authentication
  String _generateNonce() {
    final bytes = List<int>.generate(32, (i) => _random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Compute HMAC-SHA256 signature
  String _computeHmac(String message, Uint8List secretKey) {
    final messageBytes = utf8.encode(message);
    final hmac = Hmac(sha256, secretKey);
    final digest = hmac.convert(messageBytes);
    return base64Encode(digest.bytes);
  }

  /// Verify HMAC signature
  bool _verifyHmac(String message, String signature, Uint8List secretKey) {
    final expectedSignature = _computeHmac(message, secretKey);
    return expectedSignature == signature;
  }

  /// Create handshake message (client → server)
  SyncMessage createHandshake(String groupId, String deviceId) {
    return SyncMessage.handshake(
      groupId: groupId,
      deviceId: deviceId,
    );
  }

  /// Process handshake and create challenge (server side)
  SyncMessage processHandshake(SyncMessage handshake) {
    if (handshake.type != MessageType.handshake) {
      return SyncMessage.createError(
        groupId: handshake.groupId,
        errorMessage: 'Expected HANDSHAKE message',
      );
    }

    if (handshake.groupId == null) {
      return SyncMessage.createError(
        errorMessage: 'Missing groupId in handshake',
      );
    }

    // Generate challenge nonce
    final nonce = _generateNonce();
    return SyncMessage.challenge(
      groupId: handshake.groupId!,
      nonce: nonce,
    );
  }

  /// Process challenge and create response (client side)
  Future<SyncMessage> processChallenge(
    SyncMessage challenge,
    String deviceId,
  ) async {
    if (challenge.type != MessageType.challenge) {
      return SyncMessage.createError(
        groupId: challenge.groupId,
        deviceId: deviceId,
        errorMessage: 'Expected CHALLENGE message',
      );
    }

    if (challenge.groupId == null || challenge.nonce == null) {
      return SyncMessage.createError(
        deviceId: deviceId,
        errorMessage: 'Missing groupId or nonce in challenge',
      );
    }

    // Get group to retrieve secret key
    final group = await _groupDao.getGroupById(challenge.groupId!);
    if (group == null) {
      return SyncMessage.createError(
        groupId: challenge.groupId,
        deviceId: deviceId,
        errorMessage: 'Group not found',
      );
    }

    // Compute HMAC signature using group secret key
    final signature = _computeHmac(challenge.nonce!, group.secretKey);
    debugPrint('SyncProtocol: Client computing signature');
    debugPrint('  - nonce: ${challenge.nonce}');
    debugPrint('  - computed signature: $signature');
    debugPrint('  - secret key length: ${group.secretKey.length} bytes');

    return SyncMessage.response(
      groupId: challenge.groupId!,
      deviceId: deviceId,
      signature: signature,
    );
  }

  /// Verify response (server side)
  Future<bool> verifyResponse(
    SyncMessage response,
    String nonce,
  ) async {
    if (response.type != MessageType.response) {
      debugPrint('SyncProtocol: verifyResponse failed - wrong type: ${response.type}');
      return false;
    }

    if (response.groupId == null || response.signature == null) {
      debugPrint('SyncProtocol: verifyResponse failed - missing groupId or signature');
      return false;
    }

    // Get group to retrieve secret key
    final group = await _groupDao.getGroupById(response.groupId!);
    if (group == null) {
      debugPrint('SyncProtocol: verifyResponse failed - group not found: ${response.groupId}');
      return false;
    }

    // Verify HMAC signature
    final isValid = _verifyHmac(nonce, response.signature!, group.secretKey);
    if (!isValid) {
      debugPrint('SyncProtocol: HMAC verification failed');
      debugPrint('  - nonce: $nonce');
      debugPrint('  - received signature: ${response.signature}');
      debugPrint('  - expected signature: ${_computeHmac(nonce, group.secretKey)}');
      debugPrint('  - secret key length: ${group.secretKey.length} bytes');
    } else {
      debugPrint('SyncProtocol: HMAC verification successful');
    }
    return isValid;
  }

  /// Create data request message
  SyncMessage createDataRequest(
    String groupId,
    String deviceId,
    int? lastSyncedAt,
  ) {
    return SyncMessage.dataRequest(
      groupId: groupId,
      deviceId: deviceId,
      lastSyncedAt: lastSyncedAt,
    );
  }

  /// Process data request and create data response
  Future<SyncMessage> processDataRequest(SyncMessage request) async {
    if (request.type != MessageType.dataRequest) {
      return SyncMessage.createError(
        groupId: request.groupId,
        errorMessage: 'Expected DATA_REQUEST message',
      );
    }

    if (request.groupId == null || request.deviceId == null) {
      return SyncMessage.createError(
        errorMessage: 'Missing groupId or deviceId in data request',
      );
    }

    try {
      // Gather all group data
      final group = await _groupDao.getGroupById(request.groupId!);
      if (group == null) {
        return SyncMessage.createError(
          groupId: request.groupId,
          deviceId: request.deviceId,
          errorMessage: 'Group not found',
        );
      }

      final members = await _memberDao.getMembersByGroupId(request.groupId!);
      final expenses = await _expenseDao.getExpensesByGroupId(request.groupId!);
      final settlements = await _settlementDao.getSettlementsByGroupId(request.groupId!);

      // Filter by lastSyncedAt if provided (only send new/updated data)
      final lastSynced = request.lastSyncedAt;
      final filteredExpenses = lastSynced != null
          ? expenses.where((e) => e.updatedAt > lastSynced).toList()
          : expenses;
      final filteredMembers = lastSynced != null
          ? members.where((m) => m.addedAt > lastSynced).toList()
          : members;
      final filteredSettlements = lastSynced != null
          ? settlements.where((s) => s.createdAt > lastSynced).toList()
          : settlements;

      // Serialize data to JSON
      final groupData = {
        'group': group.toJson(),
        'members': filteredMembers.map((m) => m.toJson()).toList(),
        'expenses': filteredExpenses.map((e) => e.toJson()).toList(),
        'settlements': filteredSettlements.map((s) => s.toJson()).toList(),
      };

      return SyncMessage.dataResponse(
        groupId: request.groupId!,
        deviceId: request.deviceId!,
        groupData: groupData,
      );
    } catch (e) {
      return SyncMessage.createError(
        groupId: request.groupId,
        deviceId: request.deviceId,
        errorMessage: 'Error gathering data: $e',
      );
    }
  }

  /// Process data response and merge into local database
  Future<SyncResult> processDataResponse(SyncMessage response) async {
    if (response.type != MessageType.dataResponse) {
      return SyncResult(
        success: false,
        error: 'Expected DATA_RESPONSE message',
      );
    }

    if (response.groupId == null || response.groupData == null) {
      return SyncResult(
        success: false,
        error: 'Missing groupId or groupData in data response',
      );
    }

    try {
      final data = response.groupData!;
      int syncedMembers = 0;
      int syncedExpenses = 0;
      int syncedSettlements = 0;

      // Merge group metadata (update timestamps, knownDeviceIds, etc.)
      if (data['group'] != null) {
        final remoteGroup = Group.fromJson(data['group'] as Map<String, dynamic>);
        final localGroup = await _groupDao.getGroupById(response.groupId!);

        if (localGroup != null) {
          // Merge known device IDs
          final mergedDeviceIds = <String>{
            ...localGroup.knownDeviceIds,
            ...remoteGroup.knownDeviceIds,
          }.toList();

          // Update group with merged data (keep local updatedAt if newer)
          final updatedGroup = localGroup.copyWith(
            knownDeviceIds: mergedDeviceIds,
            updatedAt: remoteGroup.updatedAt > localGroup.updatedAt
                ? remoteGroup.updatedAt
                : localGroup.updatedAt,
            lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
          );
          await _groupDao.updateGroup(updatedGroup);
        }
      }

      // Merge members (upsert by ID)
      if (data['members'] != null) {
        final members = (data['members'] as List)
            .map((m) => Member.fromJson(m as Map<String, dynamic>))
            .toList();

        for (final member in members) {
          final existing = await _memberDao.getMemberById(member.id);
          if (existing == null) {
            // New member - insert
            await _memberDao.insertMember(member);
            syncedMembers++;
          }
          // Note: Members are not updated after creation (no updatedAt field)
        }
      }

      // Merge expenses (upsert by ID, newer timestamp wins)
      if (data['expenses'] != null) {
        final expenses = (data['expenses'] as List)
            .map((e) => GroupExpense.fromJson(e as Map<String, dynamic>))
            .toList();

        for (final expense in expenses) {
          final existing = await _expenseDao.getExpenseById(expense.id);
          if (existing == null || expense.updatedAt > existing.updatedAt) {
            // New or newer expense - upsert (ConflictAlgorithm.replace)
            await _expenseDao.insertExpense(expense);
            syncedExpenses++;
          }
        }
      }

      // Merge settlements (upsert by ID)
      if (data['settlements'] != null) {
        final settlements = (data['settlements'] as List)
            .map((s) => Settlement.fromJson(s as Map<String, dynamic>))
            .toList();

        for (final settlement in settlements) {
          final existing = await _settlementDao.getSettlementById(settlement.id);
          if (existing == null) {
            // New settlement - insert
            await _settlementDao.insertSettlement(settlement);
            syncedSettlements++;
          }
          // Note: Settlements are immutable (not updated after creation)
        }
      }

      return SyncResult(
        success: true,
        syncedMembers: syncedMembers,
        syncedExpenses: syncedExpenses,
        syncedSettlements: syncedSettlements,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: 'Error merging data: $e',
      );
    }
  }

  /// Create acknowledgement message
  SyncMessage createAck(String groupId, String deviceId) {
    return SyncMessage.ack(
      groupId: groupId,
      deviceId: deviceId,
    );
  }
}

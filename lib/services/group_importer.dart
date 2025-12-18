import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/group.dart';
import '../models/enums.dart';
import '../database/dao/group_dao.dart';
import '../database/dao/member_dao.dart';
import '../database/dao/group_expense_dao.dart';
import 'group_exporter.dart';

/// Import mode
enum ImportMode {
  merge, // Add new data, keep existing
  replace, // Delete all existing, import fresh
}

/// Import result
class ImportResult {
  final bool success;
  final String? groupId;
  final String? groupName;
  final int membersImported;
  final int expensesImported;
  final String? error;

  ImportResult({
    required this.success,
    this.groupId,
    this.groupName,
    this.membersImported = 0,
    this.expensesImported = 0,
    this.error,
  });
}

/// Imports group data from encrypted JSON files
class GroupImporter {
  final GroupDao _groupDao;
  final MemberDao _memberDao;
  final GroupExpenseDao _groupExpenseDao;

  GroupImporter({
    required GroupDao groupDao,
    required MemberDao memberDao,
    required GroupExpenseDao groupExpenseDao,
  })  : _groupDao = groupDao,
        _memberDao = memberDao,
        _groupExpenseDao = groupExpenseDao;

  /// Parse and validate import file without actually importing
  /// Useful for showing preview to user
  Future<ImportResult> previewImport({
    required String jsonContent,
    required Uint8List secretKey,
  }) async {
    try {
      // Parse and validate export file
      final exportFileJson = jsonDecode(jsonContent) as Map<String, dynamic>;

      // Validate required fields
      if (!exportFileJson.containsKey('type') ||
          !exportFileJson.containsKey('version') ||
          !exportFileJson.containsKey('data')) {
        throw FormatException('Invalid export file format: missing required fields');
      }

      if (exportFileJson['type'] != 'delt_group_export') {
        throw FormatException('Invalid export file type: ${exportFileJson['type']}');
      }

      final exportFile = ExportFile.fromJson(exportFileJson);

      // Decrypt payload
      final decryptedPayload = _decrypt(exportFile.data, secretKey);
      final payloadJson = jsonDecode(decryptedPayload) as Map<String, dynamic>;
      final payload = ExportPayload.fromJson(payloadJson);

      return ImportResult(
        success: true,
        groupId: payload.group.id,
        groupName: payload.group.name,
        membersImported: payload.members.length,
        expensesImported: payload.expenses.length,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        error: 'Failed to decrypt or parse file: $e',
      );
    }
  }

  /// Import group data from JSON file
  Future<ImportResult> importGroup({
    required String jsonContent,
    required Uint8List secretKey,
    required ImportMode mode,
  }) async {
    try {
      // Parse and validate export file
      final exportFileJson = jsonDecode(jsonContent) as Map<String, dynamic>;

      // Validate required fields
      if (!exportFileJson.containsKey('type') ||
          !exportFileJson.containsKey('version') ||
          !exportFileJson.containsKey('data')) {
        throw FormatException('Invalid export file format: missing required fields');
      }

      if (exportFileJson['type'] != 'delt_group_export') {
        throw FormatException('Invalid export file type: ${exportFileJson['type']}');
      }

      final exportFile = ExportFile.fromJson(exportFileJson);

      // Validate version
      if (exportFile.version > GroupExporter.version) {
        return ImportResult(
          success: false,
          error:
              'Import file version ${exportFile.version} is not supported. Please update the app.',
        );
      }

      // Decrypt payload
      final decryptedPayload = _decrypt(exportFile.data, secretKey);
      final payloadJson = jsonDecode(decryptedPayload) as Map<String, dynamic>;
      final payload = ExportPayload.fromJson(payloadJson);

      // Check if group already exists
      final existingGroup = await _groupDao.getGroupById(payload.group.id);

      switch (mode) {
        case ImportMode.replace:
          // Delete existing data if present
          if (existingGroup != null) {
            await _groupExpenseDao.deleteAllExpensesByGroupId(payload.group.id);
            await _memberDao.deleteAllMembersByGroupId(payload.group.id);
            await _groupDao.deleteGroup(existingGroup.id);
          }

          // Import everything fresh
          await _importFresh(payload);
          break;

        case ImportMode.merge:
          if (existingGroup != null) {
            // Merge with existing data
            await _mergeData(payload, existingGroup);
          } else {
            // No existing group, just import
            await _importFresh(payload);
          }
          break;
      }

      return ImportResult(
        success: true,
        groupId: payload.group.id,
        groupName: payload.group.name,
        membersImported: payload.members.length,
        expensesImported: payload.expenses.length,
      );
    } catch (e, stackTrace) {
      debugPrint('Import error: $e');
      debugPrint('Stack trace: $stackTrace');
      return ImportResult(
        success: false,
        error: 'Import failed: $e',
      );
    }
  }

  /// Import data fresh (no existing group)
  Future<void> _importFresh(ExportPayload payload) async {
    // Update group state to ACTIVE (since we're importing from another device)
    final updatedGroup = payload.group.copyWith(
      shareState: ShareState.active,
      isSharedAcrossDevices: true,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _groupDao.insertGroup(updatedGroup);

    // Import members
    for (var member in payload.members) {
      await _memberDao.insertMember(member);
    }

    // Import expenses
    for (var expense in payload.expenses) {
      await _groupExpenseDao.insertExpense(expense);
    }
  }

  /// Merge imported data with existing group
  Future<void> _mergeData(ExportPayload payload, Group existingGroup) async {
    // Update group metadata (take newer timestamp)
    final updatedGroup = payload.group.updatedAt > existingGroup.updatedAt
        ? payload.group.copyWith(
            shareState: ShareState.active,
            isSharedAcrossDevices: true,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
        : existingGroup.copyWith(
            shareState: ShareState.active,
            isSharedAcrossDevices: true,
          );

    await _groupDao.updateGroup(updatedGroup);

    // Merge members (add new ones, skip existing)
    final existingMembers =
        await _memberDao.getMembersByGroupId(existingGroup.id);
    final existingMemberIds = existingMembers.map((m) => m.id).toSet();

    for (var member in payload.members) {
      if (!existingMemberIds.contains(member.id)) {
        await _memberDao.insertMember(member);
      }
    }

    // Merge expenses (add new ones, skip existing)
    final existingExpenses =
        await _groupExpenseDao.getExpensesByGroupId(existingGroup.id);
    final existingExpenseIds = existingExpenses.map((e) => e.id).toSet();

    for (var expense in payload.expenses) {
      if (!existingExpenseIds.contains(expense.id)) {
        await _groupExpenseDao.insertExpense(expense);
      }
    }
  }

  /// Decrypt data using AES-128-CBC with the group's secret key
  String _decrypt(String encryptedData, Uint8List secretKey) {
    // Derive AES key from secret (take first 16 bytes for AES-128)
    final aesKey = secretKey.sublist(0, 16);
    final key = encrypt_pkg.Key(aesKey);

    // Decode from Base64
    final combined = base64Decode(encryptedData);

    // Extract IV (first 16 bytes) and encrypted data
    final iv = encrypt_pkg.IV(combined.sublist(0, 16));
    final encryptedBytes = combined.sublist(16);

    // Decrypt
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc),
    );
    final encrypted = encrypt_pkg.Encrypted(encryptedBytes);

    return encrypter.decrypt(encrypted, iv: iv);
  }
}

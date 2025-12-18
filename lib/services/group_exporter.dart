import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import '../models/group.dart';
import '../models/member.dart';
import '../models/group_expense.dart';

/// Export file format
class ExportFile {
  final int version;
  final String groupId;
  final String groupName;
  final int exportedAt;
  final bool encrypted;
  final String data;

  ExportFile({
    required this.version,
    required this.groupId,
    required this.groupName,
    required this.exportedAt,
    required this.encrypted,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'groupId': groupId,
      'groupName': groupName,
      'exportedAt': exportedAt,
      'encrypted': encrypted,
      'data': data,
    };
  }

  factory ExportFile.fromJson(Map<String, dynamic> json) {
    return ExportFile(
      version: json['version'] as int,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      exportedAt: json['exportedAt'] as int,
      encrypted: json['encrypted'] as bool,
      data: json['data'] as String,
    );
  }
}

/// Export payload (encrypted data)
class ExportPayload {
  final Group group;
  final List<Member> members;
  final List<GroupExpense> expenses;

  ExportPayload({
    required this.group,
    required this.members,
    required this.expenses,
  });

  Map<String, dynamic> toJson() {
    return {
      'group': group.toJson(),
      'members': members.map((m) => m.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
    };
  }

  factory ExportPayload.fromJson(Map<String, dynamic> json) {
    return ExportPayload(
      group: Group.fromJson(json['group'] as Map<String, dynamic>),
      members: (json['members'] as List<dynamic>)
          .map((m) => Member.fromJson(m as Map<String, dynamic>))
          .toList(),
      expenses: (json['expenses'] as List<dynamic>)
          .map((e) => GroupExpense.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Exports group data to encrypted JSON for manual sharing
class GroupExporter {
  static const int version = 1;

  /// Export group data to encrypted JSON string
  ///
  /// Returns JSON string ready to be saved to file
  static String exportGroup({
    required Group group,
    required List<Member> members,
    required List<GroupExpense> expenses,
  }) {
    // Create payload
    final payload = ExportPayload(
      group: group,
      members: members,
      expenses: expenses,
    );

    // Serialize payload to JSON
    final payloadJson = jsonEncode(payload.toJson());

    // Encrypt with group secret key
    final encryptedData = _encrypt(payloadJson, group.secretKey);

    // Create export file
    final exportFile = ExportFile(
      version: version,
      groupId: group.id,
      groupName: group.name,
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      encrypted: true,
      data: encryptedData,
    );

    // Return as JSON
    return jsonEncode(exportFile.toJson());
  }

  /// Encrypt data using AES-128-CBC with the group's secret key
  static String _encrypt(String data, Uint8List secretKey) {
    // Derive AES key from secret (take first 16 bytes for AES-128)
    final aesKey = secretKey.sublist(0, 16);
    final key = encrypt_pkg.Key(aesKey);

    // Generate random IV
    final random = Random.secure();
    final ivBytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      ivBytes[i] = random.nextInt(256);
    }
    final iv = encrypt_pkg.IV(ivBytes);

    // Encrypt
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(data, iv: iv);

    // Combine IV + encrypted data and encode as Base64
    final combined = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return base64Encode(combined);
  }

  /// Get suggested filename for export
  static String getSuggestedFilename(Group group) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedName = group.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'delt_${sanitizedName}_$timestamp.json';
  }
}

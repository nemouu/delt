import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/member.dart';
import '../../models/enums.dart';
import '../database_helper.dart';

/// Data Access Object for Member
class MemberDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new member
  Future<int> insertMember(Member member) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get members by group ID
  Future<List<Member>> getMembersByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'members',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'addedAt ASC',
    );

    return maps.map((map) => Member.fromMap(map)).toList();
  }

  /// Get member by ID
  Future<Member?> getMemberById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Member.fromMap(maps.first);
  }

  /// Get admin members of a group
  Future<List<Member>> getAdminsByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'members',
      where: 'groupId = ? AND role = ?',
      whereArgs: [groupId, 'admin'],
      orderBy: 'addedAt ASC',
    );

    return maps.map((map) => Member.fromMap(map)).toList();
  }

  /// Update member
  Future<int> updateMember(Member member) async {
    final db = await _dbHelper.database;
    return await db.update(
      'members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  /// Delete member
  Future<int> deleteMember(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'members',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all members of a group (called when group is deleted)
  Future<int> deleteAllMembersByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'members',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
  }

  /// Check if member is admin
  Future<bool> isAdmin(String memberId) async {
    final member = await getMemberById(memberId);
    if (member == null) return false;
    return member.role == MemberRole.admin;
  }

  /// Get member count for a group
  Future<int> getMemberCount(String groupId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM members WHERE groupId = ?',
      [groupId],
    );

    return result.first['count'] as int;
  }
}

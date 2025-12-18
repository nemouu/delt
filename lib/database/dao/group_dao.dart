import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/group.dart';
import '../database_helper.dart';

/// Data Access Object for Group
class GroupDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new group
  Future<int> insertGroup(Group group) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'groups',
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all groups (sorted by name)
  Future<List<Group>> getAllGroups() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      orderBy: 'name ASC',
    );

    return maps.map((map) => Group.fromMap(map)).toList();
  }

  /// Get group by ID
  Future<Group?> getGroupById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Group.fromMap(maps.first);
  }

  /// Get shared groups (isSharedAcrossDevices = true)
  Future<List<Group>> getSharedGroups() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: 'isSharedAcrossDevices = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Group.fromMap(map)).toList();
  }

  /// Check if any group has shared state
  Future<bool> hasSharedGroups() async {
    final groups = await getSharedGroups();
    return groups.isNotEmpty;
  }

  /// Get the personal group (isPersonal = true)
  Future<Group?> getPersonalGroup() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: 'isPersonal = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Group.fromMap(maps.first);
  }

  /// Update group
  Future<int> updateGroup(Group group) async {
    final db = await _dbHelper.database;
    return await db.update(
      'groups',
      group.toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  /// Delete group (cascades to members, expenses, settlements)
  Future<int> deleteGroup(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'groups',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update last synced timestamp
  Future<int> updateLastSyncedAt(String groupId, int timestamp) async {
    final db = await _dbHelper.database;
    return await db.update(
      'groups',
      {'lastSyncedAt': timestamp, 'updatedAt': timestamp},
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  /// Update last QR generated timestamp
  Future<int> updateLastQRGeneratedAt(String groupId, int timestamp) async {
    final db = await _dbHelper.database;
    return await db.update(
      'groups',
      {'lastQRGeneratedAt': timestamp, 'updatedAt': timestamp},
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }
}

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/settlement.dart';
import '../database_helper.dart';

/// Data Access Object for Settlement
class SettlementDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new settlement
  Future<int> insertSettlement(Settlement settlement) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'settlements',
      settlement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get settlements by group ID (sorted by date descending)
  Future<List<Settlement>> getSettlementsByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settlements',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'date DESC, createdAt DESC',
    );

    return maps.map((map) => Settlement.fromMap(map)).toList();
  }

  /// Get settlement by ID
  Future<Settlement?> getSettlementById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settlements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Settlement.fromMap(maps.first);
  }

  /// Get settlements involving a specific member (as payer or payee)
  Future<List<Settlement>> getSettlementsForMember(
    String groupId,
    String memberId,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settlements',
      where: 'groupId = ? AND (payerId = ? OR payeeId = ?)',
      whereArgs: [groupId, memberId, memberId],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Settlement.fromMap(map)).toList();
  }

  /// Delete settlement
  Future<int> deleteSettlement(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'settlements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all settlements for a group
  Future<int> deleteAllSettlementsByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'settlements',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
  }

  /// Get settlement count for a group
  Future<int> getSettlementCount(String groupId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM settlements WHERE groupId = ?',
      [groupId],
    );

    return result.first['count'] as int;
  }
}

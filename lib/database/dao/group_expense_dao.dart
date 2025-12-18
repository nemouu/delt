import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/group_expense.dart';
import '../database_helper.dart';

/// Data Access Object for GroupExpense
class GroupExpenseDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new group expense
  Future<int> insertExpense(GroupExpense expense) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'group_expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get expenses by group ID (sorted by date descending)
  Future<List<GroupExpense>> getExpensesByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'group_expenses',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'date DESC, createdAt DESC',
    );

    return maps.map((map) => GroupExpense.fromMap(map)).toList();
  }

  /// Get expense by ID
  Future<GroupExpense?> getExpenseById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'group_expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return GroupExpense.fromMap(maps.first);
  }

  /// Get expenses paid by a specific member
  Future<List<GroupExpense>> getExpensesPaidBy(
    String groupId,
    String memberId,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'group_expenses',
      where: 'groupId = ? AND paidBy = ?',
      whereArgs: [groupId, memberId],
      orderBy: 'date DESC',
    );

    return maps.map((map) => GroupExpense.fromMap(map)).toList();
  }

  /// Get unsettled expenses for a group
  Future<List<GroupExpense>> getUnsettledExpenses(String groupId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'group_expenses',
      where: 'groupId = ? AND isSettled = ?',
      whereArgs: [groupId, 0],
      orderBy: 'date DESC',
    );

    return maps.map((map) => GroupExpense.fromMap(map)).toList();
  }

  /// Update expense
  Future<int> updateExpense(GroupExpense expense) async {
    final db = await _dbHelper.database;
    return await db.update(
      'group_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  /// Delete expense
  Future<int> deleteExpense(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'group_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all expenses for a group
  Future<int> deleteAllExpensesByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'group_expenses',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
  }

  /// Get total amount paid by a member
  Future<double> getTotalPaidByMember(
    String groupId,
    String memberId,
  ) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM group_expenses WHERE groupId = ? AND paidBy = ?',
      [groupId, memberId],
    );

    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }

    return result.first['total'] as double;
  }

  /// Get expense count for a group
  Future<int> getExpenseCount(String groupId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM group_expenses WHERE groupId = ?',
      [groupId],
    );

    return result.first['count'] as int;
  }

  /// Mark expense as settled
  Future<int> markAsSettled(String expenseId, bool settled) async {
    final db = await _dbHelper.database;
    return await db.update(
      'group_expenses',
      {
        'isSettled': settled ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }
}

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/personal_expense.dart';
import '../database_helper.dart';

/// Data Access Object for PersonalExpense
class PersonalExpenseDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new personal expense
  Future<int> insertExpense(PersonalExpense expense) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'personal_expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all personal expenses (sorted by date descending)
  Future<List<PersonalExpense>> getAllExpenses() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'personal_expenses',
      orderBy: 'date DESC, createdAt DESC',
    );

    return maps.map((map) => PersonalExpense.fromMap(map)).toList();
  }

  /// Get expense by ID
  Future<PersonalExpense?> getExpenseById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'personal_expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return PersonalExpense.fromMap(maps.first);
  }

  /// Get expenses by date range
  Future<List<PersonalExpense>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'personal_expenses',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );

    return maps.map((map) => PersonalExpense.fromMap(map)).toList();
  }

  /// Get expenses by category
  Future<List<PersonalExpense>> getExpensesByCategory(String category) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'personal_expenses',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date DESC',
    );

    return maps.map((map) => PersonalExpense.fromMap(map)).toList();
  }

  /// Update expense
  Future<int> updateExpense(PersonalExpense expense) async {
    final db = await _dbHelper.database;
    return await db.update(
      'personal_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  /// Delete expense
  Future<int> deleteExpense(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'personal_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all expenses
  Future<int> deleteAllExpenses() async {
    final db = await _dbHelper.database;
    return await db.delete('personal_expenses');
  }

  /// Get total spending
  Future<double> getTotalSpending() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM personal_expenses',
    );

    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }

    return result.first['total'] as double;
  }

  /// Get total spending by currency
  Future<Map<String, double>> getTotalSpendingByCurrency() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT currency, SUM(amount) as total FROM personal_expenses GROUP BY currency',
    );

    final Map<String, double> totals = {};
    for (var row in result) {
      totals[row['currency'] as String] = row['total'] as double;
    }

    return totals;
  }
}

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/user.dart';
import '../database_helper.dart';

/// Data Access Object for User
class UserDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new user
  Future<int> insertUser(User user) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'user',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the user (should only be one)
  Future<User?> getUser() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('user', limit: 1);

    if (maps.isEmpty) {
      return null;
    }

    return User.fromMap(maps.first);
  }

  /// Update user
  Future<int> updateUser(User user) async {
    final db = await _dbHelper.database;
    return await db.update(
      'user',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Delete user
  Future<int> deleteUser(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'user',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Check if user exists
  Future<bool> userExists() async {
    final user = await getUser();
    return user != null;
  }
}

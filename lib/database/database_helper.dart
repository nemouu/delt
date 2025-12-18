import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;

/// Database helper for encrypted SQLite database
/// Using SQLCipher for encryption with user's PIN-derived passphrase
class DatabaseHelper {
  static const String _databaseName = 'delt_database.db';
  static const int _databaseVersion = 10;

  // Singleton instance
  static DatabaseHelper? _instance;
  static sqflite.Database? _database;

  DatabaseHelper._();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  /// Get database instance (must call openDatabase first)
  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    throw Exception('Database not initialized. Call openDatabase() first.');
  }

  /// Open database with encryption passphrase
  /// passphrase should be derived from user's PIN
  Future<sqflite.Database> openDatabase(String passphrase) async {
    if (_database != null) {
      return _database!;
    }

    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);

    _database = await sqflite.openDatabase(
      path,
      password: passphrase,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _database!;
  }

  /// Close database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Create tables
  Future<void> _onCreate(sqflite.Database db, int version) async {
    // User table
    await db.execute('''
      CREATE TABLE user (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        currencies TEXT NOT NULL,
        defaultCurrency TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Personal expenses table
    await db.execute('''
      CREATE TABLE personal_expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        groupExpenseId TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Groups table
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        secretKey BLOB NOT NULL,
        createdBy TEXT NOT NULL,
        currencies TEXT NOT NULL,
        defaultCurrency TEXT NOT NULL,
        isPersonal INTEGER NOT NULL DEFAULT 0,
        shareState TEXT NOT NULL,
        isSharedAcrossDevices INTEGER NOT NULL,
        knownDeviceIds TEXT NOT NULL,
        syncMethod TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        lastSyncedAt INTEGER,
        lastQRGeneratedAt INTEGER
      )
    ''');

    // Members table
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        name TEXT NOT NULL,
        colorHex TEXT NOT NULL,
        role TEXT NOT NULL,
        joinMethod TEXT NOT NULL,
        addedAt INTEGER NOT NULL,
        addedBy TEXT NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Index for members by groupId
    await db.execute('''
      CREATE INDEX idx_members_groupId ON members(groupId)
    ''');

    // Group expenses table
    await db.execute('''
      CREATE TABLE group_expenses (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        paidBy TEXT NOT NULL,
        splitBetween TEXT NOT NULL,
        splitType TEXT NOT NULL,
        splitDetails TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        deviceId TEXT NOT NULL,
        isSettled INTEGER NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Index for group expenses by groupId
    await db.execute('''
      CREATE INDEX idx_group_expenses_groupId ON group_expenses(groupId)
    ''');

    // Settlements table
    await db.execute('''
      CREATE TABLE settlements (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        payerId TEXT NOT NULL,
        payeeId TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        createdAt INTEGER NOT NULL,
        deviceId TEXT NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Index for settlements by groupId
    await db.execute('''
      CREATE INDEX idx_settlements_groupId ON settlements(groupId)
    ''');

    // Trusted WiFi networks table
    await db.execute('''
      CREATE TABLE trusted_wifi_networks (
        id TEXT PRIMARY KEY,
        ssid TEXT NOT NULL,
        bssid TEXT,
        displayName TEXT NOT NULL,
        networkType TEXT NOT NULL,
        linkedGroupId TEXT,
        addedAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(sqflite.Database db, int oldVersion, int newVersion) async {
    // Handle migrations
    // NOTE: Versions < 8 are no longer supported. Users should export data from old version first.
    if (oldVersion < 9) {
      // Migration from version 8 to 9: Add isPersonal column to groups table
      await db.execute('ALTER TABLE groups ADD COLUMN isPersonal INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 10) {
      // Migration from version 9 to 10: Add defaultCurrency columns
      // For user table
      await db.execute('ALTER TABLE user ADD COLUMN defaultCurrency TEXT');

      // Set default currency from first currency in currencies list
      final users = await db.query('user');
      for (final user in users) {
        final currenciesJson = user['currencies'] as String;
        final currencies = (jsonDecode(currenciesJson) as List<dynamic>)
            .map((e) => e as String)
            .toList();
        final defaultCurrency = currencies.isNotEmpty ? currencies.first : 'EUR';
        await db.update(
          'user',
          {'defaultCurrency': defaultCurrency},
          where: 'id = ?',
          whereArgs: [user['id']],
        );
      }

      // Make defaultCurrency NOT NULL after setting values
      // Note: SQLite doesn't support modifying column constraints, so we accept NULL for now

      // For groups table
      await db.execute('ALTER TABLE groups ADD COLUMN defaultCurrency TEXT');

      // Set default currency from first currency in currencies list
      final groups = await db.query('groups');
      for (final group in groups) {
        final currenciesJson = group['currencies'] as String;
        final currencies = (jsonDecode(currenciesJson) as List<dynamic>)
            .map((e) => e as String)
            .toList();
        final defaultCurrency = currencies.isNotEmpty ? currencies.first : 'EUR';
        await db.update(
          'groups',
          {'defaultCurrency': defaultCurrency},
          where: 'id = ?',
          whereArgs: [group['id']],
        );
      }
    }
  }

  /// Check if database exists (to determine if PIN is already set up)
  static Future<bool> databaseExists() async {
    try {
      final Directory documentsDirectory =
          await getApplicationDocumentsDirectory();
      final String path = join(documentsDirectory.path, _databaseName);
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete database (for testing or account reset)
  static Future<void> deleteDatabase() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/trusted_wifi_network.dart';
import '../database_helper.dart';

/// Data Access Object for TrustedWifiNetwork
class TrustedWifiNetworkDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new trusted network
  Future<int> insertNetwork(TrustedWifiNetwork network) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'trusted_wifi_networks',
      network.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all trusted networks
  Future<List<TrustedWifiNetwork>> getAllNetworks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trusted_wifi_networks',
      orderBy: 'displayName ASC',
    );

    return maps.map((map) => TrustedWifiNetwork.fromMap(map)).toList();
  }

  /// Get network by SSID
  Future<TrustedWifiNetwork?> getNetworkBySSID(String ssid) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trusted_wifi_networks',
      where: 'ssid = ?',
      whereArgs: [ssid],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return TrustedWifiNetwork.fromMap(maps.first);
  }

  /// Get network by ID
  Future<TrustedWifiNetwork?> getNetworkById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trusted_wifi_networks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return TrustedWifiNetwork.fromMap(maps.first);
  }

  /// Get networks linked to a specific group
  Future<List<TrustedWifiNetwork>> getNetworksByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trusted_wifi_networks',
      where: 'linkedGroupId = ?',
      whereArgs: [groupId],
    );

    return maps.map((map) => TrustedWifiNetwork.fromMap(map)).toList();
  }

  /// Check if network is trusted
  Future<bool> isNetworkTrusted(String ssid) async {
    final network = await getNetworkBySSID(ssid);
    return network != null;
  }

  /// Update network
  Future<int> updateNetwork(TrustedWifiNetwork network) async {
    final db = await _dbHelper.database;
    return await db.update(
      'trusted_wifi_networks',
      network.toMap(),
      where: 'id = ?',
      whereArgs: [network.id],
    );
  }

  /// Delete network
  Future<int> deleteNetwork(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'trusted_wifi_networks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete networks linked to a group (when group is deleted)
  Future<int> deleteNetworksByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'trusted_wifi_networks',
      where: 'linkedGroupId = ? AND networkType = ?',
      whereArgs: [groupId, 'groupSpecific'],
    );
  }

  /// Delete network by SSID
  Future<int> deleteNetworkBySSID(String ssid) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'trusted_wifi_networks',
      where: 'ssid = ?',
      whereArgs: [ssid],
    );
  }

  /// Get trusted network count
  Future<int> getNetworkCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM trusted_wifi_networks',
    );

    return result.first['count'] as int;
  }
}

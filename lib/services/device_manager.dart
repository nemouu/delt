import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Device manager for handling device identification and metadata
/// Generates and stores a unique device ID for sync purposes
class DeviceManager {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';

  // Singleton instance
  static DeviceManager? _instance;
  static DeviceManager get instance {
    _instance ??= DeviceManager._();
    return _instance!;
  }

  DeviceManager._();

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// Get or generate device ID
  /// Device ID is a UUID that uniquely identifies this app installation
  /// It's used to track which device created expenses/settlements
  Future<String> getDeviceId() async {
    // Return cached value if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // Try to load from storage
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    // Generate new ID if not exists
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Get device name (for display in sync UI)
  /// Returns a user-friendly name like "Alice's Phone"
  Future<String> getDeviceName() async {
    // Return cached value if available
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    // Try to load from storage
    final prefs = await SharedPreferences.getInstance();
    String? deviceName = prefs.getString(_deviceNameKey);

    // Use default if not set
    if (deviceName == null) {
      deviceName = 'My Device';
    }

    _cachedDeviceName = deviceName;
    return deviceName;
  }

  /// Set device name
  /// Called when user sets their name, or can be set in settings
  Future<void> setDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, name);
    _cachedDeviceName = name;
  }

  /// Get display name combining user name and device name
  /// E.g., "Alice - Pixel 7"
  Future<String> getDisplayName(String username) async {
    final deviceName = await getDeviceName();
    if (deviceName == 'My Device') {
      return username;
    }
    return '$username - $deviceName';
  }

  /// Clear device ID and name (for testing or reset)
  Future<void> clearDeviceData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_deviceNameKey);
    _cachedDeviceId = null;
    _cachedDeviceName = null;
  }
}

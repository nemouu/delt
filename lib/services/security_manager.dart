import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Security manager for PIN-based encryption
/// Handles PIN setup, verification, and database key management
class SecurityManager {
  static const String _keyPinSalt = 'pin_salt';
  static const String _keyPinHash = 'pin_hash';
  static const String _keyDbKey = 'db_key';
  static const String _keyMasterKey = 'master_key';

  static const int _pbkdf2Iterations = 100000;
  static const int _keySize = 32; // 256 bits
  static const int _saltSize = 32; // 256 bits

  final FlutterSecureStorage _storage;

  SecurityManager()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  /// Check if PIN has been set up
  Future<bool> isPinSetup() async {
    final pinHash = await _storage.read(key: _keyPinHash);
    final dbKey = await _storage.read(key: _keyDbKey);
    return pinHash != null && dbKey != null;
  }

  /// Set up a new PIN and generate encryption keys
  /// Returns true if successful, false otherwise
  Future<bool> setupPin(String pin) async {
    try {
      // Generate random salt for PIN hashing
      final salt = _generateRandomBytes(_saltSize);

      // Hash the PIN with PBKDF2
      final pinHash = _hashPin(pin, salt);

      // Generate random database encryption key
      final dbKey = _generateRandomBytes(_keySize);

      // Get or create master key
      final masterKey = await _getOrCreateMasterKey();

      // Encrypt the database key with master key
      final encryptedDbKey = _encryptData(dbKey, masterKey);

      // Store everything in secure storage
      await _storage.write(key: _keyPinSalt, value: base64Encode(salt));
      await _storage.write(key: _keyPinHash, value: base64Encode(pinHash));
      await _storage.write(
        key: _keyDbKey,
        value: base64Encode(encryptedDbKey),
      );

      return true;
    } catch (e) {
      debugPrint('SecurityManager.setupPin error: $e');
      return false;
    }
  }

  /// Validate PIN and retrieve database encryption key
  /// Returns database passphrase (as String) if PIN is valid, null otherwise
  Future<String?> unlockWithPin(String pin) async {
    try {
      // Get stored salt and hash
      final saltString = await _storage.read(key: _keyPinSalt);
      final storedHashString = await _storage.read(key: _keyPinHash);

      if (saltString == null || storedHashString == null) {
        return null;
      }

      final salt = base64Decode(saltString);
      final storedHash = base64Decode(storedHashString);

      // Hash the entered PIN
      final enteredHash = _hashPin(pin, salt);

      // Compare hashes (constant-time comparison)
      if (!_constantTimeEquals(enteredHash, storedHash)) {
        return null;
      }

      // PIN is valid, decrypt database key
      final encryptedDbKeyString = await _storage.read(key: _keyDbKey);
      if (encryptedDbKeyString == null) {
        return null;
      }

      final encryptedDbKey = base64Decode(encryptedDbKeyString);
      final masterKey = await _getOrCreateMasterKey();
      final dbKey = _decryptData(encryptedDbKey, masterKey);

      // Return as hex string (SQLCipher expects passphrase as string)
      return _bytesToHex(dbKey);
    } catch (e) {
      debugPrint('SecurityManager.unlockWithPin error: $e');
      return null;
    }
  }

  /// Change the PIN
  /// Returns true if successful, false if old PIN is incorrect
  Future<bool> changePin(String oldPin, String newPin) async {
    // First verify old PIN and get database key
    final dbKeyString = await unlockWithPin(oldPin);
    if (dbKeyString == null) {
      return false;
    }

    try {
      final dbKey = _hexToBytes(dbKeyString);

      // Generate new salt
      final newSalt = _generateRandomBytes(_saltSize);

      // Hash new PIN
      final newPinHash = _hashPin(newPin, newSalt);

      // Re-encrypt database key (it stays the same, just PIN changes)
      final masterKey = await _getOrCreateMasterKey();
      final encryptedDbKey = _encryptData(dbKey, masterKey);

      // Update stored values
      await _storage.write(key: _keyPinSalt, value: base64Encode(newSalt));
      await _storage.write(key: _keyPinHash, value: base64Encode(newPinHash));
      await _storage.write(
        key: _keyDbKey,
        value: base64Encode(encryptedDbKey),
      );

      return true;
    } catch (e) {
      debugPrint('SecurityManager.changePin error: $e');
      return false;
    }
  }

  /// Clear all security data (use with caution - data will be lost!)
  Future<void> clearAllData() async {
    await _storage.deleteAll();
  }

  // Private helper methods

  /// Generate random bytes using secure random
  Uint8List _generateRandomBytes(int size) {
    final random = Random.secure();
    final bytes = Uint8List(size);
    for (int i = 0; i < size; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Hash PIN using PBKDF2 with HMAC-SHA256
  Uint8List _hashPin(String pin, Uint8List salt) {
    final pbkdf2 = Pbkdf2(
      iterations: _pbkdf2Iterations,
      hashAlgorithm: sha256,
    );

    return Uint8List.fromList(
      pbkdf2.generateKey(
        password: pin,
        salt: salt,
        keyLength: _keySize,
      ),
    );
  }

  /// Get or create master encryption key
  Future<Uint8List> _getOrCreateMasterKey() async {
    final masterKeyString = await _storage.read(key: _keyMasterKey);

    if (masterKeyString != null) {
      return base64Decode(masterKeyString);
    }

    // Create new master key
    final masterKey = _generateRandomBytes(_keySize);
    await _storage.write(key: _keyMasterKey, value: base64Encode(masterKey));
    return masterKey;
  }

  /// Encrypt data using AES-256-GCM
  Uint8List _encryptData(Uint8List data, Uint8List key) {
    final encryptKey = encrypt_pkg.Key(key);
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(encryptKey, mode: encrypt_pkg.AESMode.gcm),
    );

    final encrypted = encrypter.encryptBytes(data, iv: iv);

    // Prepend IV to encrypted data (needed for decryption)
    final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
    result.setRange(0, iv.bytes.length, iv.bytes);
    result.setRange(iv.bytes.length, result.length, encrypted.bytes);

    return result;
  }

  /// Decrypt data using AES-256-GCM
  Uint8List _decryptData(Uint8List encryptedData, Uint8List key) {
    // Extract IV (first 16 bytes)
    final iv = encrypt_pkg.IV(encryptedData.sublist(0, 16));

    // Extract encrypted data (rest)
    final encrypted = encrypt_pkg.Encrypted(encryptedData.sublist(16));

    final encryptKey = encrypt_pkg.Key(key);
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(encryptKey, mode: encrypt_pkg.AESMode.gcm),
    );

    return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
  }

  /// Constant-time comparison to prevent timing attacks
  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }

    return result == 0;
  }

  /// Convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convert hex string to bytes
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

/// PBKDF2 implementation
class Pbkdf2 {
  final int iterations;
  final Hash hashAlgorithm;

  Pbkdf2({
    required this.iterations,
    required this.hashAlgorithm,
  });

  List<int> generateKey({
    required String password,
    required Uint8List salt,
    required int keyLength,
  }) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(hashAlgorithm, passwordBytes);

    final blocks = <int>[];
    final blockCount = (keyLength / hashAlgorithm.convert([]).bytes.length).ceil();

    for (int i = 1; i <= blockCount; i++) {
      blocks.addAll(_generateBlock(hmac, salt, i));
    }

    return blocks.sublist(0, keyLength);
  }

  List<int> _generateBlock(Hmac hmac, Uint8List salt, int blockNumber) {
    // U1 = PRF(password, salt || blockNumber)
    final blockBytes = Uint8List(4);
    blockBytes[0] = (blockNumber >> 24) & 0xff;
    blockBytes[1] = (blockNumber >> 16) & 0xff;
    blockBytes[2] = (blockNumber >> 8) & 0xff;
    blockBytes[3] = blockNumber & 0xff;

    final saltWithBlock = Uint8List.fromList([...salt, ...blockBytes]);
    var u = hmac.convert(saltWithBlock).bytes;
    final result = List<int>.from(u);

    // U2 = PRF(password, U1), U3 = PRF(password, U2), ...
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    return result;
  }
}

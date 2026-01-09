import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/group.dart';
import '../../models/enums.dart';
import '../../database/dao/group_dao.dart';
import '../../database/dao/trusted_wifi_network_dao.dart';
import '../device_manager.dart';
import 'sync_protocol.dart';
import 'sync_message.dart';
import 'wifi_network_transport.dart';

/// Sync status for a group
enum SyncStatus {
  idle, // Not syncing
  discovering, // Discovering peers
  connecting, // Connecting to peer
  authenticating, // Authenticating with peer
  syncing, // Exchanging data
  completed, // Sync completed successfully
  failed, // Sync failed
}

/// Sync event for UI updates
class SyncEvent {
  final String groupId;
  final SyncStatus status;
  final String? message;
  final SyncResult? result;
  final DateTime timestamp;

  SyncEvent({
    required this.groupId,
    required this.status,
    this.message,
    this.result,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'SyncEvent($groupId: $status - $message)';
}

/// Main sync service - orchestrates sync operations
class SyncService {
  // Singleton instance
  static SyncService? _instance;
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  SyncService._();

  final _groupDao = GroupDao();
  final _networkDao = TrustedWifiNetworkDao();
  final _networkInfo = NetworkInfo();
  final _deviceManager = DeviceManager.instance;
  final _protocol = SyncProtocol();
  final _transport = WiFiNetworkTransport();

  final StreamController<SyncEvent> _syncEventController =
      StreamController<SyncEvent>.broadcast();

  bool _isRunning = false;
  String? _currentDeviceId;

  /// Stream of sync events for UI updates
  Stream<SyncEvent> get onSyncEvent => _syncEventController.stream;

  /// Check if sync service is running
  bool get isRunning => _isRunning;

  /// Initialize the sync service
  /// Should be called when app opens or resumes
  Future<void> initialize() async {
    if (_isRunning) {
      return;
    }

    try {
      _isRunning = true;

      // Get device ID
      _currentDeviceId = await _deviceManager.getDeviceId();

      // Register handler for incoming connections
      _transport.onIncomingConnection = handleIncomingConnection;

      // Start transport server
      await _transport.startServer(_currentDeviceId!);

      debugPrint('SyncService: Initialized on port ${_transport.listeningPort}');
    } catch (e) {
      debugPrint('SyncService: Failed to initialize: $e');
      _isRunning = false;
    }
  }

  /// Check current network and auto-sync if on trusted network
  /// This should be called when app opens or resumes
  Future<void> checkAndSyncOnTrustedNetwork() async {
    if (!_isRunning) {
      await initialize();
    }

    try {
      // Check location permission (required for WiFi SSID on Android 10+)
      final status = await Permission.location.status;
      if (!status.isGranted) {
        debugPrint('SyncService: Location permission not granted, cannot check WiFi');
        return;
      }

      // Get current WiFi SSID
      final ssid = await _networkInfo.getWifiName();
      if (ssid == null) {
        debugPrint('SyncService: Not connected to WiFi');
        return;
      }

      // Remove quotes from iOS SSID
      final cleanSSID = ssid.replaceAll('"', '');
      debugPrint('SyncService: Connected to WiFi: $cleanSSID');

      // Check if this is a trusted network
      final trustedNetworks = await _networkDao.getAllNetworks();
      final matchingNetworks = trustedNetworks.where(
        (network) => network.ssid == cleanSSID,
      ).toList();

      if (matchingNetworks.isEmpty) {
        debugPrint('SyncService: WiFi not trusted, skipping auto-sync');
        return;
      }

      debugPrint('SyncService: WiFi is trusted, starting auto-sync for ${matchingNetworks.length} groups');

      // Sync all groups linked to this network
      for (final network in matchingNetworks) {
        if (network.linkedGroupId != null) {
          await syncGroup(network.linkedGroupId!);
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error in checkAndSyncOnTrustedNetwork: $e');
    }
  }

  /// Manually trigger sync for a specific group
  Future<SyncResult> syncGroup(String groupId) async {
    if (!_isRunning) {
      await initialize();
    }

    try {
      _emitEvent(SyncEvent(
        groupId: groupId,
        status: SyncStatus.discovering,
        message: 'Discovering peers...',
      ));

      // Get group
      final group = await _groupDao.getGroupById(groupId);
      if (group == null) {
        _emitEvent(SyncEvent(
          groupId: groupId,
          status: SyncStatus.failed,
          message: 'Group not found',
        ));
        return SyncResult(success: false, error: 'Group not found');
      }

      // Check if group is shared
      if (!group.isSharedAcrossDevices) {
        debugPrint('SyncService: Group is not shared, skipping sync');
        return SyncResult(success: false, error: 'Group is not shared');
      }

      // Discover peers
      final peers = await _transport.discoverPeers();
      debugPrint('SyncService: Discovered ${peers.length} peers');

      if (peers.isEmpty) {
        _emitEvent(SyncEvent(
          groupId: groupId,
          status: SyncStatus.failed,
          message: 'No peers discovered',
        ));
        return SyncResult(success: false, error: 'No peers found');
      }

      // Try to sync with each peer
      SyncResult? lastResult;
      int successfulSyncs = 0;

      for (final peer in peers) {
        try {
          final result = await _syncWithPeer(group, peer);
          if (result.success) {
            successfulSyncs++;
            lastResult = result;
          }
        } catch (e) {
          debugPrint('SyncService: Failed to sync with peer ${peer.host}: $e');
        }
      }

      if (successfulSyncs > 0) {
        // Update lastSyncedAt
        final updatedGroup = group.copyWith(
          lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
          shareState: ShareState.active, // Mark as active after first successful sync
        );
        await _groupDao.updateGroup(updatedGroup);

        _emitEvent(SyncEvent(
          groupId: groupId,
          status: SyncStatus.completed,
          message: 'Synced with $successfulSyncs device(s)',
          result: lastResult,
        ));

        return lastResult ?? SyncResult(success: true);
      } else {
        _emitEvent(SyncEvent(
          groupId: groupId,
          status: SyncStatus.failed,
          message: 'Failed to sync with any peers',
        ));
        return SyncResult(success: false, error: 'No successful syncs');
      }
    } catch (e) {
      debugPrint('SyncService: Error syncing group: $e');
      _emitEvent(SyncEvent(
        groupId: groupId,
        status: SyncStatus.failed,
        message: 'Error: $e',
      ));
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Sync with a specific peer
  Future<SyncResult> _syncWithPeer(Group group, DiscoveredPeer peer) async {
    PeerConnection? connection;

    try {
      _emitEvent(SyncEvent(
        groupId: group.id,
        status: SyncStatus.connecting,
        message: 'Connecting to ${peer.host}...',
      ));

      // Connect to peer
      connection = await _transport.connectToPeer(peer);
      if (connection == null) {
        return SyncResult(success: false, error: 'Failed to connect');
      }

      _emitEvent(SyncEvent(
        groupId: group.id,
        status: SyncStatus.authenticating,
        message: 'Authenticating...',
      ));

      // STEP 1: Send HANDSHAKE
      final handshake = _protocol.createHandshake(group.id, _currentDeviceId!);
      await _transport.sendMessage(connection, handshake);

      // STEP 2: Receive CHALLENGE
      final challenge = await _transport.receiveMessage(connection);
      if (challenge == null || challenge.type != MessageType.challenge) {
        return SyncResult(success: false, error: 'Invalid challenge');
      }

      // STEP 3: Send RESPONSE
      final response = await _protocol.processChallenge(challenge, _currentDeviceId!);
      await _transport.sendMessage(connection, response);

      // STEP 4: Receive authentication result (could be error or data request)
      final authResult = await _transport.receiveMessage(connection);
      if (authResult == null) {
        return SyncResult(success: false, error: 'Authentication timeout');
      }

      if (authResult.type == MessageType.error) {
        return SyncResult(success: false, error: authResult.error ?? 'Authentication failed');
      }

      _emitEvent(SyncEvent(
        groupId: group.id,
        status: SyncStatus.syncing,
        message: 'Exchanging data...',
      ));

      // STEP 5: Send DATA_REQUEST
      final dataRequest = _protocol.createDataRequest(
        group.id,
        _currentDeviceId!,
        group.lastSyncedAt,
      );
      await _transport.sendMessage(connection, dataRequest);

      // STEP 6: Receive DATA_RESPONSE
      final dataResponse = await _transport.receiveMessage(connection);
      if (dataResponse == null || dataResponse.type != MessageType.dataResponse) {
        return SyncResult(success: false, error: 'Invalid data response');
      }

      // STEP 7: Process data and merge into database
      final result = await _protocol.processDataResponse(dataResponse);

      // STEP 8: Send ACK
      final ack = _protocol.createAck(group.id, _currentDeviceId!);
      await _transport.sendMessage(connection, ack);

      debugPrint('SyncService: Sync completed with ${peer.host}: $result');
      return result;
    } catch (e) {
      debugPrint('SyncService: Error syncing with peer: $e');
      return SyncResult(success: false, error: e.toString());
    } finally {
      await connection?.close();
    }
  }

  /// Handle incoming sync connection (server side)
  Future<void> handleIncomingConnection(PeerConnection connection) async {
    String? nonce;
    String? groupId;

    try {
      debugPrint('SyncService: Handling incoming connection from ${connection.remoteHost}');

      // STEP 1: Receive HANDSHAKE
      final handshake = await _transport.receiveMessage(connection);
      if (handshake == null) {
        debugPrint('SyncService: Failed to receive handshake');
        return;
      }

      groupId = handshake.groupId;

      // STEP 2: Process handshake and send CHALLENGE
      final challenge = _protocol.processHandshake(handshake);
      if (challenge.type == MessageType.error) {
        await _transport.sendMessage(connection, challenge);
        return;
      }

      nonce = challenge.nonce!;
      await _transport.sendMessage(connection, challenge);

      // STEP 3: Receive RESPONSE
      final response = await _transport.receiveMessage(connection);
      if (response == null) {
        debugPrint('SyncService: Failed to receive response');
        return;
      }

      // STEP 4: Verify response and send result
      final isValid = await _protocol.verifyResponse(response, nonce);
      if (!isValid) {
        final errorMsg = SyncMessage.createError(
          groupId: groupId,
          errorMessage: 'Authentication failed',
        );
        await _transport.sendMessage(connection, errorMsg);
        return;
      }

      debugPrint('SyncService: Authentication successful');

      // STEP 4.5: Send ACK to confirm successful authentication
      final authAck = _protocol.createAck(groupId!, _currentDeviceId!);
      await _transport.sendMessage(connection, authAck);

      // STEP 5: Receive DATA_REQUEST
      final dataRequest = await _transport.receiveMessage(connection);
      if (dataRequest == null || dataRequest.type != MessageType.dataRequest) {
        debugPrint('SyncService: Invalid data request');
        return;
      }

      // STEP 6: Process data request and send DATA_RESPONSE
      final dataResponse = await _protocol.processDataRequest(dataRequest);
      await _transport.sendMessage(connection, dataResponse);

      if (dataResponse.type == MessageType.error) {
        debugPrint('SyncService: Error creating data response');
        return;
      }

      // STEP 7: Receive ACK
      final ack = await _transport.receiveMessage(connection);
      if (ack == null || ack.type != MessageType.ack) {
        debugPrint('SyncService: Failed to receive ACK');
        return;
      }

      debugPrint('SyncService: Sync completed successfully with ${connection.remoteHost}');
    } catch (e) {
      debugPrint('SyncService: Error handling incoming connection: $e');
      if (groupId != null) {
        final errorMsg = SyncMessage.createError(
          groupId: groupId,
          errorMessage: 'Server error: $e',
        );
        await _transport.sendMessage(connection, errorMsg);
      }
    } finally {
      await connection.close();
    }
  }

  /// Emit sync event
  void _emitEvent(SyncEvent event) {
    debugPrint('SyncService: ${event.toString()}');
    _syncEventController.add(event);
  }

  /// Stop the sync service
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    await _transport.close();
    debugPrint('SyncService: Stopped');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await _syncEventController.close();
  }
}

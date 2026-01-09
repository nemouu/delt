import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'sync_message.dart';

/// Discovered peer device on the network
class DiscoveredPeer {
  final String deviceId;
  final String host;
  final int port;
  final DateTime discoveredAt;

  DiscoveredPeer({
    required this.deviceId,
    required this.host,
    required this.port,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  @override
  String toString() => 'DiscoveredPeer(deviceId: $deviceId, host: $host, port: $port)';
}

/// WiFi Network Transport for device-to-device sync over local network
/// Uses TCP sockets for communication
class WiFiNetworkTransport {
  static const int _defaultPort = 8765;
  static const Duration _messageTimeout = Duration(seconds: 30);

  ServerSocket? _serverSocket;
  int? _listeningPort;
  bool _isRunning = false;

  final List<DiscoveredPeer> _discoveredPeers = [];
  final StreamController<DiscoveredPeer> _peerDiscoveryController =
      StreamController<DiscoveredPeer>.broadcast();

  /// Callback for handling incoming connections (server side)
  Future<void> Function(PeerConnection)? onIncomingConnection;

  /// Stream of discovered peers
  Stream<DiscoveredPeer> get onPeerDiscovered => _peerDiscoveryController.stream;

  /// Check if transport is running
  bool get isRunning => _isRunning;

  /// Get listening port (null if not running)
  int? get listeningPort => _listeningPort;

  /// Start listening for incoming connections
  /// Returns the port number being listened on
  Future<int> startServer(String deviceId) async {
    if (_isRunning) {
      return _listeningPort!;
    }

    try {
      // Bind to any available port (or default port if available)
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _defaultPort,
        shared: true,
      );

      _listeningPort = _serverSocket!.port;
      _isRunning = true;

      debugPrint('WiFiNetworkTransport: Server started on port $_listeningPort');

      // Listen for incoming connections
      _serverSocket!.listen(
        (Socket client) {
          debugPrint('WiFiNetworkTransport: Client connected from ${client.remoteAddress.address}:${client.remotePort}');
          _handleClient(client);
        },
        onError: (error) {
          debugPrint('WiFiNetworkTransport: Server error: $error');
        },
        onDone: () {
          debugPrint('WiFiNetworkTransport: Server closed');
        },
      );

      return _listeningPort!;
    } catch (e) {
      debugPrint('WiFiNetworkTransport: Failed to start server: $e');
      rethrow;
    }
  }

  /// Stop the server
  Future<void> stopServer() async {
    if (!_isRunning || _serverSocket == null) {
      return;
    }

    try {
      await _serverSocket!.close();
      _serverSocket = null;
      _listeningPort = null;
      _isRunning = false;
      _discoveredPeers.clear();
      debugPrint('WiFiNetworkTransport: Server stopped');
    } catch (e) {
      debugPrint('WiFiNetworkTransport: Error stopping server: $e');
    }
  }

  /// Handle incoming client connection
  void _handleClient(Socket client) {
    if (onIncomingConnection == null) {
      debugPrint('WiFiNetworkTransport: No handler registered for incoming connections');
      client.close();
      return;
    }

    // Create PeerConnection and pass to handler
    final connection = PeerConnection(client);
    onIncomingConnection!(connection).catchError((error) {
      debugPrint('WiFiNetworkTransport: Error handling incoming connection: $error');
      client.close();
    });
  }

  /// Discover peers on the local network
  /// For now, this is a simple broadcast/scan mechanism
  /// TODO: Implement proper NSD (Network Service Discovery) when packages are stable
  Future<List<DiscoveredPeer>> discoverPeers({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _discoveredPeers.clear();

    try {
      // Get local IP address
      final localAddresses = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      if (localAddresses.isEmpty) {
        debugPrint('WiFiNetworkTransport: No network interfaces found');
        return [];
      }

      // For each network interface, scan the subnet
      for (final interface in localAddresses) {
        if (interface.addresses.isEmpty) continue;

        final localIp = interface.addresses.first.address;
        debugPrint('WiFiNetworkTransport: Scanning subnet for $localIp');

        // Extract subnet (e.g., 192.168.1.x)
        final parts = localIp.split('.');
        if (parts.length != 4) continue;

        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

        // Scan common IP range (1-254)
        // In production, this should use NSD for efficiency
        final futures = <Future>[];
        for (int i = 1; i <= 254; i++) {
          final targetIp = '$subnet.$i';
          if (targetIp == localIp) continue; // Skip self

          futures.add(_probePeer(targetIp, _defaultPort));
        }

        // Wait for all probes with timeout
        await Future.wait(futures).timeout(
          timeout,
          onTimeout: () {
            debugPrint('WiFiNetworkTransport: Discovery timeout');
            return [];
          },
        );
      }

      debugPrint('WiFiNetworkTransport: Discovered ${_discoveredPeers.length} peers');
      return List.from(_discoveredPeers);
    } catch (e) {
      debugPrint('WiFiNetworkTransport: Error discovering peers: $e');
      return [];
    }
  }

  /// Probe a specific IP:port to see if a Delt peer is running
  Future<void> _probePeer(String host, int port) async {
    Socket? socket;
    try {
      // Try to connect with short timeout
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 500),
      );

      // Send a simple ping to verify it's a Delt service
      // For now, just assume any service on this port is Delt
      // TODO: Send proper handshake to verify

      final peer = DiscoveredPeer(
        deviceId: 'unknown', // Will be discovered during handshake
        host: host,
        port: port,
      );

      _discoveredPeers.add(peer);
      _peerDiscoveryController.add(peer);

      debugPrint('WiFiNetworkTransport: Discovered peer at $host:$port');
    } catch (e) {
      // Connection failed - not a peer or not reachable
      // This is expected for most IPs, so don't log
    } finally {
      socket?.close();
    }
  }

  /// Connect to a peer and exchange messages
  /// Returns a bidirectional stream for sending/receiving messages
  Future<PeerConnection?> connectToPeer(DiscoveredPeer peer) async {
    try {
      final socket = await Socket.connect(
        peer.host,
        peer.port,
        timeout: const Duration(seconds: 5),
      );

      debugPrint('WiFiNetworkTransport: Connected to peer ${peer.host}:${peer.port}');

      return PeerConnection(socket);
    } catch (e) {
      debugPrint('WiFiNetworkTransport: Failed to connect to peer: $e');
      return null;
    }
  }

  /// Send a message to a peer
  Future<bool> sendMessage(PeerConnection connection, SyncMessage message) async {
    try {
      final messageBytes = message.toBytes();
      final length = messageBytes.length;

      // Send message length first (4 bytes, big endian)
      final lengthBytes = Uint8List(4);
      lengthBytes.buffer.asByteData().setUint32(0, length, Endian.big);
      connection.socket.add(lengthBytes);

      // Send message data
      connection.socket.add(messageBytes);
      await connection.socket.flush();

      debugPrint('WiFiNetworkTransport: Sent ${message.type} message ($length bytes)');
      return true;
    } catch (e) {
      debugPrint('WiFiNetworkTransport: Failed to send message: $e');
      return false;
    }
  }

  /// Receive a message from a peer
  Future<SyncMessage?> receiveMessage(PeerConnection connection) async {
    try {
      // Read message length (4 bytes)
      final lengthBytes = await connection.readBytes(4, timeout: _messageTimeout);

      if (lengthBytes == null || lengthBytes.length != 4) {
        debugPrint('WiFiNetworkTransport: Failed to read message length');
        return null;
      }

      final length = lengthBytes.buffer.asByteData().getUint32(0, Endian.big);

      if (length > 10 * 1024 * 1024) {
        // Sanity check: reject messages > 10MB
        debugPrint('WiFiNetworkTransport: Message too large: $length bytes');
        return null;
      }

      // Read message data
      final messageBytes = await connection.readBytes(length, timeout: _messageTimeout);

      if (messageBytes == null || messageBytes.length != length) {
        debugPrint('WiFiNetworkTransport: Failed to read message data');
        return null;
      }

      final message = SyncMessage.fromBytes(messageBytes);
      debugPrint('WiFiNetworkTransport: Received ${message.type} message ($length bytes)');

      return message;
    } catch (e) {
      debugPrint('WiFiNetworkTransport: Failed to receive message: $e');
      return null;
    }
  }

  /// Close transport and cleanup
  Future<void> close() async {
    await stopServer();
    await _peerDiscoveryController.close();
  }
}

/// Represents a connection to a peer device
class PeerConnection {
  final Socket socket;
  late final Stream<Uint8List> _stream;
  final List<int> _buffer = [];
  StreamSubscription<Uint8List>? _subscription;
  bool _isClosed = false;

  PeerConnection(this.socket) {
    // Create a broadcast stream so we can read from the socket multiple times
    _stream = socket.asBroadcastStream();

    // Subscribe to the stream and buffer all incoming data
    _subscription = _stream.listen(
      (data) {
        _buffer.addAll(data);
      },
      onError: (error) {
        debugPrint('PeerConnection: Socket error: $error');
      },
      onDone: () {
        debugPrint('PeerConnection: Socket closed');
        _isClosed = true;
      },
    );
  }

  String get remoteHost => socket.remoteAddress.address;
  int get remotePort => socket.remotePort;

  /// Read exactly n bytes from the buffered stream
  Future<Uint8List?> readBytes(int n, {Duration timeout = const Duration(seconds: 30)}) async {
    final startTime = DateTime.now();

    while (!_isClosed) {
      // Check if we have enough data in the buffer
      if (_buffer.length >= n) {
        final data = Uint8List.fromList(_buffer.sublist(0, n));
        _buffer.removeRange(0, n);
        return data;
      }

      // Check timeout
      if (DateTime.now().difference(startTime) > timeout) {
        return null;
      }

      // Wait a bit before checking again
      await Future.delayed(const Duration(milliseconds: 10));
    }

    return null; // Socket closed before receiving enough data
  }

  /// Close the connection
  Future<void> close() async {
    await _subscription?.cancel();
    await socket.close();
    _isClosed = true;
  }

  @override
  String toString() => 'PeerConnection($remoteHost:$remotePort)';
}

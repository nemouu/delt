import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/group.dart';
import '../models/member.dart';
import '../models/enums.dart';
import '../database/dao/group_dao.dart';
import '../database/dao/member_dao.dart';
import '../database/dao/user_dao.dart';

/// Screen for scanning QR codes to join groups
class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay with scanning frame
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: Container(),
          ),
          // Instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black.withValues(alpha: 0.7),
              child: const Text(
                'Point your camera at the QR code to join a group',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _hasScanned = true;
    });

    _processQRCode(code);
  }

  Future<void> _processQRCode(String qrData) async {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;

      // Validate QR code format
      if (data['type'] != 'delt_group_invite') {
        throw Exception('Invalid QR code. This is not a Delt group invite.');
      }

      // Extract group data
      final groupId = data['groupId'] as String;
      final groupName = data['groupName'] as String;
      final secretKeyBase64 = data['secretKey'] as String;
      final currencies = List<String>.from(data['currencies'] as List);
      final createdBy = data['createdBy'] as String;
      final createdAt = data['createdAt'] as int;

      final secretKey = base64Decode(secretKeyBase64);

      // Check if already in this group
      final groupDao = GroupDao();
      final existingGroup = await groupDao.getGroupById(groupId);

      if (existingGroup != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are already a member of this group'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Show join dialog
      if (mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => _JoinGroupDialog(
            groupName: groupName,
            currencies: currencies,
          ),
        );

        if (result == true && mounted) {
          await _joinGroup(
            groupId: groupId,
            groupName: groupName,
            secretKey: Uint8List.fromList(secretKey),
            currencies: currencies,
            createdBy: createdBy,
            createdAt: createdAt,
          );
        } else {
          setState(() {
            _hasScanned = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _hasScanned = false;
        });
      }
    }
  }

  Future<void> _joinGroup({
    required String groupId,
    required String groupName,
    required Uint8List secretKey,
    required List<String> currencies,
    required String createdBy,
    required int createdAt,
  }) async {
    try {
      final groupDao = GroupDao();
      final memberDao = MemberDao();
      final userDao = UserDao();
      final user = await userDao.getUser();

      if (user == null) {
        throw Exception('User not found');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      // Create group locally
      final group = Group(
        id: groupId,
        name: groupName,
        secretKey: secretKey,
        createdBy: createdBy,
        currencies: currencies,
        shareState: ShareState.active,
        isSharedAcrossDevices: true,
        knownDeviceIds: [],
        syncMethod: SyncMethod.manual,
        createdAt: createdAt,
        updatedAt: now,
        lastSyncedAt: now,
        lastQRGeneratedAt: null,
      );

      await groupDao.insertGroup(group);

      // Add self as member
      final uuid = const Uuid();
      final memberId = uuid.v4();
      final member = Member(
        id: memberId,
        groupId: groupId,
        name: user.username,
        colorHex: _generateRandomColor(),
        role: MemberRole.member,
        joinMethod: JoinMethod.code,
        addedAt: now,
        addedBy: user.id,
      );

      await memberDao.insertMember(member);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined group "$groupName"'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return to groups list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining group: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _hasScanned = false;
        });
      }
    }
  }

  String _generateRandomColor() {
    final colors = [
      '#F44336', '#E91E63', '#9C27B0', '#673AB7', '#3F51B5',
      '#2196F3', '#03A9F4', '#00BCD4', '#009688', '#4CAF50',
      '#8BC34A', '#CDDC39', '#FFC107', '#FF9800', '#FF5722',
    ];
    return colors[Random().nextInt(colors.length)];
  }
}

/// Custom painter for scanner overlay
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;

    // Draw dark overlay with transparent scan area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
          const Radius.circular(16),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corner brackets
    final bracketPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final bracketLength = 30.0;

    // Top-left
    canvas.drawLine(
      Offset(left, top + bracketLength),
      Offset(left, top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + bracketLength, top),
      bracketPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(left + scanAreaSize - bracketLength, top),
      Offset(left + scanAreaSize, top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + bracketLength),
      bracketPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(left, top + scanAreaSize - bracketLength),
      Offset(left, top + scanAreaSize),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + bracketLength, top + scanAreaSize),
      bracketPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(left + scanAreaSize - bracketLength, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize - bracketLength),
      Offset(left + scanAreaSize, top + scanAreaSize),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dialog for confirming group join
class _JoinGroupDialog extends StatelessWidget {
  final String groupName;
  final List<String> currencies;

  const _JoinGroupDialog({
    required this.groupName,
    required this.currencies,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join Group'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do you want to join this group?',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Text(
            groupName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Currencies: ${currencies.join(', ')}',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Join'),
        ),
      ],
    );
  }
}

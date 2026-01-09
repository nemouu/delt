import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/group.dart';
import '../models/enums.dart';
import '../database/dao/group_dao.dart';

/// Screen for displaying group QR code for sharing
class GroupQRScreen extends StatefulWidget {
  final String groupId;

  const GroupQRScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupQRScreen> createState() => _GroupQRScreenState();
}

class _GroupQRScreenState extends State<GroupQRScreen> {
  final _groupDao = GroupDao();
  Group? _group;
  bool _isLoading = true;
  String? _qrData;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final group = await _groupDao.getGroupById(widget.groupId);
      if (group != null) {
        // Create QR code data
        final qrData = _generateQRData(group);

        // Update last QR generated timestamp
        final updatedGroup = group.copyWith(
          lastQRGeneratedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _groupDao.updateGroup(updatedGroup);

        setState(() {
          _group = updatedGroup;
          _qrData = qrData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateQRData(Group group) {
    final inviteData = {
      'type': 'delt_group_invite',
      'version': 1,
      'groupId': group.id,
      'groupName': group.name,
      'secretKey': base64Encode(group.secretKey),
      'currencies': group.currencies,
      'defaultCurrency': group.defaultCurrency,
      'createdBy': group.createdBy,
      'createdAt': group.createdAt,
      'syncMethod': group.syncMethod.toStr(),
      'isSharedAcrossDevices': group.isSharedAcrossDevices,
    };

    return jsonEncode(inviteData);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Share Group'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null || _qrData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Share Group'),
        ),
        body: const Center(
          child: Text('Group not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Group'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Group info
            Text(
              _group!.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan this QR code to join the group',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _qrData!,
                version: QrVersions.auto,
                size: 280,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            const SizedBox(height: 32),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'How to share',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Have the other person open Delt\n'
                    '2. They tap "Join Group" on the Groups tab\n'
                    '3. They scan this QR code\n'
                    '4. They enter their name to join',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Warning
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only share this QR code with people you trust. It contains your group\'s encryption key.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

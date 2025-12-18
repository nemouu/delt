import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/member.dart';
import '../models/enums.dart';
import '../database/dao/member_dao.dart';
import '../database/dao/user_dao.dart';

/// Screen for manually adding a member to a group
class AddMemberScreen extends StatefulWidget {
  final String groupId;

  const AddMemberScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _memberDao = MemberDao();
  final _userDao = UserDao();

  MemberRole _selectedRole = MemberRole.member;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Member'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _addMember,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Name input
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Member Name',
                hintText: 'Enter member name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: TextInputAction.done,
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Role selector
            DropdownButtonFormField<MemberRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: const [
                DropdownMenuItem(
                  value: MemberRole.member,
                  child: Text('Member'),
                ),
                DropdownMenuItem(
                  value: MemberRole.admin,
                  child: Text('Admin'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
            ),
            const SizedBox(height: 24),

            // Info card
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
                        'Member Roles',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Members can add expenses and view balances\n'
                    '• Admins can also manage group settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
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

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = await _userDao.getUser();
      if (user == null) {
        throw Exception('User not found');
      }

      final uuid = const Uuid();
      final memberId = uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      final member = Member(
        id: memberId,
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        colorHex: _generateRandomColor(),
        role: _selectedRole,
        joinMethod: JoinMethod.manual,
        addedAt: now,
        addedBy: user.id,
      );

      await _memberDao.insertMember(member);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} added to group'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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

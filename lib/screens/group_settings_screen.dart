import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/enums.dart';
import '../database/dao/group_dao.dart';
import '../database/dao/member_dao.dart';
import '../database/dao/user_dao.dart';
import '../database/dao/group_expense_dao.dart';
import 'manage_group_currencies_screen.dart';

/// Group settings screen
class GroupSettingsScreen extends StatefulWidget {
  final String groupId;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _groupDao = GroupDao();
  final _memberDao = MemberDao();
  final _userDao = UserDao();
  final _expenseDao = GroupExpenseDao();

  Group? _group;
  List<Member> _members = [];
  Member? _currentMember;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final group = await _groupDao.getGroupById(widget.groupId);
      final members = await _memberDao.getMembersByGroupId(widget.groupId);
      final user = await _userDao.getUser();

      // Find current user's member record
      Member? currentMember;
      if (user != null) {
        currentMember = members.firstWhere(
          (m) => m.name == user.username,
          orElse: () => members.first,
        );
      }

      setState(() {
        _group = group;
        _members = members;
        _currentMember = currentMember;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Group Settings'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Group Settings'),
        ),
        body: const Center(
          child: Text('Group not found'),
        ),
      );
    }

    final isAdmin = _currentMember?.role == MemberRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
      ),
      body: ListView(
        children: [
          // Group Info Section
          _buildSectionHeader('Group Information'),
          ListTile(
            leading: const Icon(Icons.label),
            title: const Text('Group Name'),
            subtitle: Text(_group!.name),
            trailing: isAdmin ? const Icon(Icons.edit) : null,
            onTap: isAdmin ? _editGroupName : null,
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Currencies'),
            subtitle: Text(_group!.currencies.join(', ')),
            trailing: isAdmin ? const Icon(Icons.chevron_right) : null,
            onTap: isAdmin ? _manageCurrencies : null,
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Members'),
            subtitle: Text('${_members.length} member${_members.length != 1 ? 's' : ''}'),
          ),

          const Divider(),

          // Danger Zone
          _buildSectionHeader('Danger Zone', color: Colors.red),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.orange),
            title: const Text(
              'Leave Group',
              style: TextStyle(color: Colors.orange),
            ),
            subtitle: const Text('You will lose access to this group'),
            onTap: _leaveGroup,
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Group',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Permanently delete this group for everyone'),
              onTap: _deleteGroup,
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color ?? Colors.grey[600],
        ),
      ),
    );
  }

  Future<void> _editGroupName() async {
    final controller = TextEditingController(text: _group!.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName != _group!.name) {
      try {
        final updatedGroup = _group!.copyWith(
          name: newName,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _groupDao.updateGroup(updatedGroup);

        setState(() {
          _group = updatedGroup;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group name updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating name: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _manageCurrencies() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageGroupCurrenciesScreen(groupId: widget.groupId),
      ),
    );

    // Reload data to reflect currency changes
    _loadData();
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text(
          'Are you sure you want to leave "${_group!.name}"?\n\n'
          'You will lose access to all group data and will need to be re-invited to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Remove current user's member record
        if (_currentMember != null) {
          await _memberDao.deleteMember(_currentMember!.id);
        }

        // Delete the group locally (they're leaving, so remove it)
        await _groupDao.deleteGroup(widget.groupId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left group successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Pop twice: settings screen and group details screen
          Navigator.pop(context);
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error leaving group: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteGroup() async {
    final expenseCount = await _expenseDao.getExpenseCount(widget.groupId);

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Are you sure you want to permanently delete "${_group!.name}"?\n\n'
          'This will delete:\n'
          '• ${_members.length} member${_members.length != 1 ? 's' : ''}\n'
          '• $expenseCount expense${expenseCount != 1 ? 's' : ''}\n'
          '• All balances and settlements\n\n'
          'This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete group (cascade will delete members, expenses, settlements)
        await _groupDao.deleteGroup(widget.groupId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group deleted'),
              backgroundColor: Colors.green,
            ),
          );
          // Pop settings screen with true to indicate deletion
          // The group details screen will handle popping back to groups list
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting group: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

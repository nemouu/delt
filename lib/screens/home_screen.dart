import 'package:flutter/material.dart';
import '../models/group.dart';
import '../database/dao/group_dao.dart';
import '../database/dao/member_dao.dart';
import '../services/sync/sync_service.dart';
import 'create_group_screen.dart';
import 'group_details_screen.dart';
import 'scan_qr_screen.dart';
import 'change_pin_screen.dart';
import 'manage_currencies_screen.dart';

/// Home screen with bottom navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GroupsTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Groups tab
class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  final _groupDao = GroupDao();
  final _memberDao = MemberDao();
  final _syncService = SyncService.instance;
  List<Group> _groups = [];
  Map<String, int> _memberCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _triggerAutoSync();
  }

  /// Trigger auto-sync if on trusted WiFi network
  Future<void> _triggerAutoSync() async {
    try {
      await _syncService.checkAndSyncOnTrustedNetwork();
      // Reload groups after sync to show updated data
      if (mounted) {
        await _loadGroups();
      }
    } catch (e) {
      // Silently ignore sync errors - sync is optional
      debugPrint('Auto-sync failed: $e');
    }
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await _groupDao.getAllGroups();
      final Map<String, int> counts = {};

      for (var group in groups) {
        final memberCount = await _memberDao.getMemberCount(group.id);
        counts[group.id] = memberCount;
      }

      // Sort: personal group first, then others alphabetically
      groups.sort((a, b) {
        if (a.isPersonal && !b.isPersonal) return -1;
        if (!a.isPersonal && b.isPersonal) return 1;
        return a.name.compareTo(b.name);
      });

      setState(() {
        _groups = groups;
        _memberCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading groups: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Join Group via QR',
            onPressed: _joinGroup,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmptyState()
              : _buildGroupsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No groups yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a group to split expenses',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _joinGroup,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Join Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final memberCount = _memberCounts[group.id] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: group.isPersonal
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                group.isPersonal ? Icons.person : Icons.groups,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (group.isPersonal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Personal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (!group.isPersonal)
                  Text('$memberCount member${memberCount != 1 ? 's' : ''}'),
                if (!group.isPersonal) const SizedBox(height: 2),
                Text(
                  'Currencies: ${group.currencies.join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupDetailsScreen(groupId: group.id),
                ),
              );

              // Reload groups if group was modified or deleted
              if (result == true) {
                _loadGroups();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _createGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );

    // Reload groups if a group was created
    if (result == true) {
      _loadGroups();
    }
  }

  Future<void> _joinGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanQRScreen(),
      ),
    );

    // Reload groups if a group was joined
    if (result == true) {
      _loadGroups();
    }
  }
}

/// Settings tab (placeholder)
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change PIN'),
            subtitle: const Text('Update your security PIN'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePinScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Manage Currencies'),
            subtitle: const Text('Add or remove default currencies'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageCurrenciesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync'),
            subtitle: const Text('Sync with nearby devices'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync - Coming soon!')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Delt',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Privacy-first expense splitting app',
              );
            },
          ),
        ],
      ),
    );
  }
}

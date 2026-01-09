import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/group.dart';
import '../models/member.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../models/trusted_wifi_network.dart';
import '../database/dao/group_dao.dart';
import '../database/dao/member_dao.dart';
import '../database/dao/user_dao.dart';
import '../database/dao/trusted_wifi_network_dao.dart';
import '../widgets/currency_picker.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Screen for creating a new group
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _groupDao = GroupDao();
  final _memberDao = MemberDao();
  final _userDao = UserDao();
  final _networkInfo = NetworkInfo();

  User? _currentUser;
  List<String> _selectedCurrencies = [];
  String? _defaultCurrency;
  bool _isCreating = false;

  // Sharing configuration
  bool _isSharedGroup = false;
  SyncMethod _syncMethod = SyncMethod.wifiNetwork;
  String? _currentWifiSSID;
  bool _trustCurrentNetwork = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCurrentNetwork();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _userDao.getUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
          // Pre-select user's currencies
          _selectedCurrencies = List.from(user.currencies);
          // Set user's default currency as the default
          _defaultCurrency = user.defaultCurrency;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCurrentNetwork() async {
    try {
      // Request location permission (required for WiFi SSID on Android 10+)
      final status = await Permission.location.request();

      if (status.isGranted) {
        final ssid = await _networkInfo.getWifiName();
        if (mounted && ssid != null) {
          setState(() {
            // Remove quotes if present (iOS returns SSID with quotes)
            _currentWifiSSID = ssid.replaceAll('"', '');
          });
        }
      } else {
        // Permission denied - WiFi name won't be available
        debugPrint('Location permission denied - cannot access WiFi SSID');
      }
    } catch (e) {
      // WiFi info not available (no permission, not connected, etc.)
      // Silently ignore - user can add networks later
      debugPrint('Error loading WiFi network: $e');
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Group name input
                  TextFormField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'e.g., Roommates, Trip to Paris',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.groups),
                    ),
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a group name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Group type selection
                  Text(
                    'Group Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: !_isSharedGroup
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: RadioListTile<bool>(
                      value: false,
                      groupValue: _isSharedGroup,
                      onChanged: (value) {
                        setState(() {
                          _isSharedGroup = value!;
                        });
                      },
                      title: const Text('Local Group'),
                      subtitle: const Text('Only on this device'),
                      secondary: const Icon(Icons.phone_android),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _isSharedGroup
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: RadioListTile<bool>(
                      value: true,
                      groupValue: _isSharedGroup,
                      onChanged: (value) {
                        setState(() {
                          _isSharedGroup = value!;
                        });
                      },
                      title: const Text('Shared Group'),
                      subtitle: const Text('Sync across devices'),
                      secondary: const Icon(Icons.sync),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Show sync configuration if shared group
                  if (_isSharedGroup) ...[
                    Text(
                      'Sync Method',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How devices will sync',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('WiFi Network'),
                          selected: _syncMethod == SyncMethod.wifiNetwork,
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                          onSelected: (selected) {
                            setState(() {
                              _syncMethod = SyncMethod.wifiNetwork;
                            });
                          },
                          avatar: const Icon(Icons.wifi, size: 18),
                        ),
                        ChoiceChip(
                          label: const Text('Bluetooth (Coming Soon)'),
                          selected: _syncMethod == SyncMethod.bluetooth,
                          onSelected: null, // Disabled for now
                          avatar: const Icon(Icons.bluetooth_disabled, size: 18),
                        ),
                        ChoiceChip(
                          label: const Text('WiFi Direct (Coming Soon)'),
                          selected: _syncMethod == SyncMethod.wifiDirect,
                          onSelected: null, // Disabled for now
                          avatar: const Icon(Icons.wifi_tethering_off, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Trust current network option
                    if (_currentWifiSSID != null && _syncMethod == SyncMethod.wifiNetwork) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.wifi, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Current WiFi: $_currentWifiSSID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              value: _trustCurrentNetwork,
                              onChanged: (value) {
                                setState(() {
                                  _trustCurrentNetwork = value ?? false;
                                });
                              },
                              title: const Text('Trust this network for auto-sync'),
                              subtitle: const Text('Automatically sync when connected to this WiFi'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isPublicNetwork(_currentWifiSSID!))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'This appears to be a public network. Only trust networks you control.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                    ] else if (_syncMethod == SyncMethod.wifiNetwork) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off, color: Colors.orange[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Not connected to WiFi. You can add trusted networks later in group settings.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],

                  // Currency selection
                  Text(
                    'Currencies',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select currencies for group expenses',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._currentUser!.currencies.map((currency) {
                        final isSelected = _selectedCurrencies.contains(currency);
                        return FilterChip(
                          label: Text(currency),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCurrencies.add(currency);
                                // If first currency selected, make it default
                                if (_defaultCurrency == null || !_selectedCurrencies.contains(_defaultCurrency!)) {
                                  _defaultCurrency = currency;
                                }
                              } else {
                                if (_selectedCurrencies.length > 1) {
                                  _selectedCurrencies.remove(currency);
                                  // If removing default currency, pick another one
                                  if (_defaultCurrency == currency) {
                                    _defaultCurrency = _selectedCurrencies.first;
                                  }
                                }
                              }
                            });
                          },
                        );
                      }),
                      // Add currency chip
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Add currencies'),
                        onPressed: _addCustomCurrency,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Show selected currencies that aren't in user's list
                  if (_selectedCurrencies.any((c) => !_currentUser!.currencies.contains(c)))
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedCurrencies
                          .where((c) => !_currentUser!.currencies.contains(c))
                          .map((currency) => Chip(
                                label: Text(currency),
                                onDeleted: () {
                                  setState(() {
                                    _selectedCurrencies.remove(currency);
                                    if (_defaultCurrency == currency && _selectedCurrencies.isNotEmpty) {
                                      _defaultCurrency = _selectedCurrencies.first;
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 24),

                  // Default currency selection
                  Text(
                    'Default Currency',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select which currency to use by default',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedCurrencies.map((currency) {
                      final isDefault = _defaultCurrency == currency;
                      return ChoiceChip(
                        label: Text(currency),
                        selected: isDefault,
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        onSelected: (selected) {
                          setState(() {
                            _defaultCurrency = currency;
                          });
                        },
                      );
                    }).toList(),
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
                              'How it works',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• You\'ll be added as the admin\n'
                          '• Add members later from group settings\n'
                          '• Share via QR code or manually add members\n'
                          '• All data is encrypted locally',
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

  Future<void> _addCustomCurrency() async {
    final result = await CurrencyPicker.show(
      context,
      selectedCurrencies: _selectedCurrencies,
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _selectedCurrencies = result;
        // If default currency is not in the new list, update it
        if (_defaultCurrency == null || !_selectedCurrencies.contains(_defaultCurrency!)) {
          _defaultCurrency = _selectedCurrencies.first;
        }
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCurrencies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one currency'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not found. Please restart the app.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final uuid = const Uuid();
      final groupId = uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Generate secret key for group encryption (32 bytes)
      final random = Random.secure();
      final secretKey = Uint8List.fromList(
        List<int>.generate(32, (i) => random.nextInt(256)),
      );

      // Create group with appropriate sharing configuration
      final group = Group(
        id: groupId,
        name: _groupNameController.text.trim(),
        secretKey: secretKey,
        createdBy: _currentUser!.id,
        currencies: _selectedCurrencies,
        defaultCurrency: _defaultCurrency ?? _selectedCurrencies.first,
        shareState: _isSharedGroup ? ShareState.pending : ShareState.local,
        isSharedAcrossDevices: _isSharedGroup,
        knownDeviceIds: [],
        syncMethod: _isSharedGroup ? _syncMethod : SyncMethod.manual,
        createdAt: now,
        updatedAt: now,
        lastSyncedAt: null,
        lastQRGeneratedAt: null,
      );

      await _groupDao.insertGroup(group);

      // Save trusted WiFi network if user chose to trust it
      if (_isSharedGroup && _trustCurrentNetwork && _currentWifiSSID != null) {
        final networkDao = TrustedWifiNetworkDao();
        final trustedNetwork = TrustedWifiNetwork(
          ssid: _currentWifiSSID!,
          displayName: _currentWifiSSID!,
          networkType: NetworkType.groupSpecific,
          linkedGroupId: groupId,
          addedAt: now,
          updatedAt: now,
        );
        await networkDao.insertNetwork(trustedNetwork);
      }

      // Add current user as admin member
      final memberId = uuid.v4();
      final member = Member(
        id: memberId,
        groupId: groupId,
        name: _currentUser!.username,
        colorHex: _generateRandomColor(),
        role: MemberRole.admin,
        joinMethod: JoinMethod.manual,
        addedAt: now,
        addedBy: _currentUser!.id,
      );

      await _memberDao.insertMember(member);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "${group.name}" created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  /// Check if WiFi network name suggests it's a public network
  bool _isPublicNetwork(String ssid) {
    final publicKeywords = [
      'guest',
      'public',
      'free',
      'open',
      'starbucks',
      'mcdonalds',
      'airport',
      'hotel',
      'cafe',
      'coffee',
      'restaurant',
      'mall',
      'library',
    ];

    final lowerSSID = ssid.toLowerCase();
    return publicKeywords.any((keyword) => lowerSSID.contains(keyword));
  }

  /// Generate a random color for the member
  String _generateRandomColor() {
    final colors = [
      '#F44336', // Red
      '#E91E63', // Pink
      '#9C27B0', // Purple
      '#673AB7', // Deep Purple
      '#3F51B5', // Indigo
      '#2196F3', // Blue
      '#03A9F4', // Light Blue
      '#00BCD4', // Cyan
      '#009688', // Teal
      '#4CAF50', // Green
      '#8BC34A', // Light Green
      '#CDDC39', // Lime
      '#FFC107', // Amber
      '#FF9800', // Orange
      '#FF5722', // Deep Orange
    ];
    return colors[Random().nextInt(colors.length)];
  }
}

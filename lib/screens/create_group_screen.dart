import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/group.dart';
import '../models/member.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../database/dao/group_dao.dart';
import '../database/dao/member_dao.dart';
import '../database/dao/user_dao.dart';
import '../widgets/currency_picker.dart';

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

  User? _currentUser;
  List<String> _selectedCurrencies = [];
  String? _defaultCurrency;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

      // Create group
      final group = Group(
        id: groupId,
        name: _groupNameController.text.trim(),
        secretKey: secretKey,
        createdBy: _currentUser!.id,
        currencies: _selectedCurrencies,
        defaultCurrency: _defaultCurrency ?? _selectedCurrencies.first,
        shareState: ShareState.local,
        isSharedAcrossDevices: false,
        knownDeviceIds: [],
        syncMethod: SyncMethod.manual,
        createdAt: now,
        updatedAt: now,
        lastSyncedAt: null,
        lastQRGeneratedAt: null,
      );

      await _groupDao.insertGroup(group);

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

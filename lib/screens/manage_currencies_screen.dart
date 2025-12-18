import 'package:flutter/material.dart';
import '../database/dao/user_dao.dart';
import '../models/user.dart';
import '../widgets/currency_picker.dart';

/// Screen for managing user's default currencies
class ManageCurrenciesScreen extends StatefulWidget {
  const ManageCurrenciesScreen({super.key});

  @override
  State<ManageCurrenciesScreen> createState() => _ManageCurrenciesScreenState();
}

class _ManageCurrenciesScreenState extends State<ManageCurrenciesScreen> {
  final _userDao = UserDao();
  User? _user;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userDao.getUser();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCurrencies() async {
    if (_user == null) return;

    final result = await CurrencyPicker.show(
      context,
      selectedCurrencies: _user!.currencies,
    );

    if (result != null && mounted) {
      setState(() {
        _isSaving = true;
      });

      try {
        final updatedUser = _user!.copyWith(
          currencies: result,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        await _userDao.updateUser(updatedUser);

        setState(() {
          _user = updatedUser;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Currencies updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating currencies: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _setDefaultCurrency(String currency) async {
    if (_user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedUser = _user!.copyWith(
        defaultCurrency: currency,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _userDao.updateUser(updatedUser);

      setState(() {
        _user = updatedUser;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Default currency set to $currency'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting default currency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeCurrency(String currency) async {
    if (_user == null) return;

    // Don't allow removing the last currency
    if (_user!.currencies.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must have at least one currency'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Don't allow removing the default currency
    if (_user!.defaultCurrency == currency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the default currency. Please set another currency as default first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final newCurrencies = List<String>.from(_user!.currencies)
        ..remove(currency);

      final updatedUser = _user!.copyWith(
        currencies: newCurrencies,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _userDao.updateUser(updatedUser);

      setState(() {
        _user = updatedUser;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $currency'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing currency: $e'),
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
          title: const Text('Manage Currencies'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Currencies'),
        ),
        body: const Center(
          child: Text('User not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Currencies'),
      ),
      body: Column(
        children: [
          // Info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These are your default currencies. They will be available when creating expenses.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Default currency selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Currency',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select which currency to use by default for new expenses',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _user!.currencies.map((currency) {
                        final isDefault = _user!.defaultCurrency == currency;
                        return ChoiceChip(
                          label: Text(currency),
                          selected: isDefault,
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                          onSelected: (selected) async {
                            if (selected && !_isSaving) {
                              await _setDefaultCurrency(currency);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Currency list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _user!.currencies.length,
              itemBuilder: (context, index) {
                final currency = _user!.currencies[index];
                final symbol = CurrencyData.getSymbol(currency);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        symbol,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(currency),
                    subtitle: Text('Symbol: $symbol'),
                    trailing: _user!.currencies.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _isSaving
                                ? null
                                : () => _removeCurrency(currency),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          // Add button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _addCurrencies,
              icon: const Icon(Icons.add),
              label: const Text('Add/Edit Currencies'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

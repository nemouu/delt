import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PIN setup screen for first-time users
class PinSetupScreen extends StatefulWidget {
  final Function(String username, List<String> currencies, String defaultCurrency, String pin) onPinSetup;

  const PinSetupScreen({
    super.key,
    required this.onPinSetup,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  final _usernameFocusNode = FocusNode();
  final _pinFocusNode = FocusNode();
  final _confirmPinFocusNode = FocusNode();

  final List<String> _availableCurrencies = [
    'EUR', 'USD', 'GBP', 'DKK', 'SEK', 'NOK', 'CHF', 'JPY', 'AUD', 'CAD'
  ];
  final List<String> _selectedCurrencies = ['EUR', 'USD'];
  String _defaultCurrency = 'EUR'; // Default currency

  int _currentStep = 0;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _usernameFocusNode.dispose();
    _pinFocusNode.dispose();
    _confirmPinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Delt'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentStep + 1) / 3,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 32),

              Expanded(
                child: _buildCurrentStep(),
              ),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentStep--;
                          _errorMessage = null;
                        });
                      },
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    onPressed: _handleNext,
                    child: Text(_currentStep == 2 ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildUsernameStep();
      case 1:
        return _buildCurrencyStep();
      case 2:
        return _buildPinStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUsernameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What should we call you?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'This will be your display name in the app',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Enter your name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          textInputAction: TextInputAction.next,
          autofocus: true,
          onSubmitted: (_) => _handleNext(),
        ),
      ],
    );
  }

  Widget _buildCurrencyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your currencies',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the currencies you\'ll use for expenses',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _availableCurrencies.length,
            itemBuilder: (context, index) {
              final currency = _availableCurrencies[index];
              final isSelected = _selectedCurrencies.contains(currency);

              return FilterChip(
                label: Text(currency),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCurrencies.add(currency);
                      // If first currency selected, make it default
                      if (_selectedCurrencies.length == 1) {
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
            },
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Default Currency',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),
        const SizedBox(height: 8),
        Text(
          'Select which currency to use by default',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
      ],
    );
  }

  Widget _buildPinStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set up your PIN',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Your PIN protects your data with encryption',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _pinController,
          focusNode: _pinFocusNode,
          decoration: InputDecoration(
            labelText: 'PIN (6 digits)',
            hintText: 'Enter 6-digit PIN',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscurePin = !_obscurePin;
                });
              },
            ),
          ),
          obscureText: _obscurePin,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textInputAction: TextInputAction.next,
          autofocus: true,
          onSubmitted: (_) => _confirmPinFocusNode.requestFocus(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPinController,
          focusNode: _confirmPinFocusNode,
          decoration: InputDecoration(
            labelText: 'Confirm PIN',
            hintText: 'Re-enter PIN',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPin ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscureConfirmPin = !_obscureConfirmPin;
                });
              },
            ),
          ),
          obscureText: _obscureConfirmPin,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => _handleNext(),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Important: There is no way to recover your data if you forget your PIN!',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleNext() {
    setState(() {
      _errorMessage = null;
    });

    switch (_currentStep) {
      case 0:
        // Validate username
        if (_usernameController.text.trim().isEmpty) {
          setState(() {
            _errorMessage = 'Please enter a username';
          });
          return;
        }
        setState(() {
          _currentStep = 1;
        });
        break;

      case 1:
        // Validate currencies
        if (_selectedCurrencies.isEmpty) {
          setState(() {
            _errorMessage = 'Please select at least one currency';
          });
          return;
        }
        setState(() {
          _currentStep = 2;
        });
        break;

      case 2:
        // Validate PIN
        final pin = _pinController.text;
        final confirmPin = _confirmPinController.text;

        if (pin.length != 6) {
          setState(() {
            _errorMessage = 'PIN must be 6 digits';
          });
          return;
        }

        if (pin != confirmPin) {
          setState(() {
            _errorMessage = 'PINs do not match';
          });
          return;
        }

        // All validated, proceed
        widget.onPinSetup(
          _usernameController.text.trim(),
          _selectedCurrencies,
          _defaultCurrency,
          pin,
        );
        break;
    }
  }
}

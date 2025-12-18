import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_manager.dart';

/// Screen for changing the user's PIN
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _securityManager = SecurityManager();
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isChanging = false;
  bool _obscureOldPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PIN'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Info card
            Container(
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
                      'Your PIN protects your encrypted database. Choose a PIN that is easy to remember but hard to guess.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Old PIN input
            TextFormField(
              controller: _oldPinController,
              decoration: InputDecoration(
                labelText: 'Current PIN',
                hintText: 'Enter your current PIN',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOldPin ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureOldPin = !_obscureOldPin;
                    });
                  },
                ),
              ),
              obscureText: _obscureOldPin,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current PIN';
                }
                if (value.length != 6) {
                  return 'PIN must be 6 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // New PIN input
            TextFormField(
              controller: _newPinController,
              decoration: InputDecoration(
                labelText: 'New PIN',
                hintText: 'Enter new 6-digit PIN',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPin ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPin = !_obscureNewPin;
                    });
                  },
                ),
              ),
              obscureText: _obscureNewPin,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a new PIN';
                }
                if (value.length != 6) {
                  return 'PIN must be 6 digits';
                }
                if (value == _oldPinController.text) {
                  return 'New PIN must be different from current PIN';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm new PIN input
            TextFormField(
              controller: _confirmPinController,
              decoration: InputDecoration(
                labelText: 'Confirm New PIN',
                hintText: 'Re-enter new PIN',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPin ? Icons.visibility : Icons.visibility_off,
                  ),
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
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _changePin(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your new PIN';
                }
                if (value != _newPinController.text) {
                  return 'PINs do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Change PIN button
            FilledButton(
              onPressed: _isChanging ? null : _changePin,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isChanging
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Change PIN',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isChanging = true;
    });

    try {
      final oldPin = _oldPinController.text;
      final newPin = _newPinController.text;

      // Verify old PIN
      final passphrase = await _securityManager.unlockWithPin(oldPin);
      if (passphrase == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect current PIN'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Change PIN
      final success = await _securityManager.changePin(oldPin, newPin);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to change PIN. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing PIN: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChanging = false;
        });
      }
    }
  }
}

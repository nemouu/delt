import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PIN unlock screen for returning users
class PinUnlockScreen extends StatefulWidget {
  final Function(String pin) onUnlock;
  final VoidCallback onUnlockFailed;
  final int attemptsRemaining;

  const PinUnlockScreen({
    super.key,
    required this.onUnlock,
    required this.onUnlockFailed,
    required this.attemptsRemaining,
  });

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _obscurePin = true;
  bool _isUnlocking = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.attemptsRemaining <= 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo/icon
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  isLocked
                      ? 'Too many attempts. Please wait.'
                      : 'Enter your PIN to unlock',
                  style: TextStyle(
                    color: isLocked ? Colors.red : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 48),

                // PIN input
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    enabled: !isLocked && !_isUnlocking,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      hintText: 'Enter 6-digit PIN',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin
                            ? Icons.visibility
                            : Icons.visibility_off),
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
                    autofocus: true,
                    onSubmitted: (_) => _handleUnlock(),
                  ),
                ),
                const SizedBox(height: 24),

                // Unlock button
                SizedBox(
                  width: 300,
                  child: FilledButton(
                    onPressed:
                        (isLocked || _isUnlocking) ? null : _handleUnlock,
                    child: _isUnlocking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unlock'),
                  ),
                ),
                const SizedBox(height: 16),

                // Attempts remaining
                if (!isLocked && widget.attemptsRemaining < 3)
                  Text(
                    'Attempts remaining: ${widget.attemptsRemaining}',
                    style: TextStyle(
                      color: widget.attemptsRemaining <= 1
                          ? Colors.red
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUnlock() async {
    final pin = _pinController.text;

    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN must be 6 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUnlocking = true;
    });

    try {
      await widget.onUnlock(pin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUnlocking = false;
          _pinController.clear();
        });
      }
    }
  }
}

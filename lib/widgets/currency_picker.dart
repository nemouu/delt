import 'package:flutter/material.dart';

/// Common currencies with their symbols
class CurrencyData {
  static const Map<String, String> currencies = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'NOK': 'kr',
    'SEK': 'kr',
    'DKK': 'kr',
    'JPY': '¥',
    'CNY': '¥',
    'INR': '₹',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'Fr',
    'BRL': 'R\$',
    'ZAR': 'R',
    'RUB': '₽',
    'KRW': '₩',
    'MXN': 'Mex\$',
    'SGD': 'S\$',
    'HKD': 'HK\$',
    'NZD': 'NZ\$',
  };

  static String getSymbol(String code) {
    return currencies[code] ?? code;
  }

  static List<String> getAllCodes() {
    return currencies.keys.toList()..sort();
  }
}

/// Multi-select currency picker dialog
class CurrencyPicker extends StatefulWidget {
  final List<String> selectedCurrencies;
  final Function(List<String>) onConfirm;

  const CurrencyPicker({
    super.key,
    required this.selectedCurrencies,
    required this.onConfirm,
  });

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> selectedCurrencies,
  }) async {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => _CurrencyPickerDialog(
        selectedCurrencies: selectedCurrencies,
      ),
    );
  }

  @override
  State<CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<CurrencyPicker> {
  late List<String> _selectedCurrencies;

  @override
  void initState() {
    super.initState();
    _selectedCurrencies = List.from(widget.selectedCurrencies);
  }

  @override
  Widget build(BuildContext context) {
    final allCurrencies = CurrencyData.getAllCodes();

    return AlertDialog(
      title: const Text('Select Currencies'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: allCurrencies.length,
          itemBuilder: (context, index) {
            final currency = allCurrencies[index];
            final symbol = CurrencyData.getSymbol(currency);
            final isSelected = _selectedCurrencies.contains(currency);

            return CheckboxListTile(
              title: Text('$currency ($symbol)'),
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedCurrencies.add(currency);
                  } else {
                    _selectedCurrencies.remove(currency);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedCurrencies.isEmpty
              ? null
              : () {
                  widget.onConfirm(_selectedCurrencies);
                  Navigator.pop(context);
                },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

/// Simple dialog version
class _CurrencyPickerDialog extends StatefulWidget {
  final List<String> selectedCurrencies;

  const _CurrencyPickerDialog({
    required this.selectedCurrencies,
  });

  @override
  State<_CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<_CurrencyPickerDialog> {
  late List<String> _selectedCurrencies;

  @override
  void initState() {
    super.initState();
    _selectedCurrencies = List.from(widget.selectedCurrencies);
  }

  @override
  Widget build(BuildContext context) {
    final allCurrencies = CurrencyData.getAllCodes();

    return AlertDialog(
      title: const Text('Select Currencies'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: allCurrencies.length,
          itemBuilder: (context, index) {
            final currency = allCurrencies[index];
            final symbol = CurrencyData.getSymbol(currency);
            final isSelected = _selectedCurrencies.contains(currency);

            return CheckboxListTile(
              title: Text('$currency ($symbol)'),
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedCurrencies.add(currency);
                  } else {
                    _selectedCurrencies.remove(currency);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedCurrencies.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedCurrencies),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

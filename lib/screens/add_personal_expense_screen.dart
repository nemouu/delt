import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/personal_expense.dart';
import '../models/categories.dart';
import '../models/receipt_data.dart';
import '../database/dao/personal_expense_dao.dart';
import '../widgets/receipt_preview_dialog.dart';
import 'receipt_capture_screen.dart';

/// Screen for adding or editing a personal expense
class AddPersonalExpenseScreen extends StatefulWidget {
  final List<String> availableCurrencies;
  final String? defaultCurrency;
  final PersonalExpense? expenseToEdit;

  const AddPersonalExpenseScreen({
    super.key,
    required this.availableCurrencies,
    this.defaultCurrency,
    this.expenseToEdit,
  });

  @override
  State<AddPersonalExpenseScreen> createState() =>
      _AddPersonalExpenseScreenState();
}

class _AddPersonalExpenseScreenState extends State<AddPersonalExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _personalExpenseDao = PersonalExpenseDao();

  String? _selectedCurrency;
  String _selectedCategory = Categories.food;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill form if editing
    if (widget.expenseToEdit != null) {
      final expense = widget.expenseToEdit!;
      _amountController.text = expense.amount.toStringAsFixed(2);
      _noteController.text = expense.note ?? '';
      _selectedCurrency = expense.currency;
      _selectedCategory = expense.category;
      _selectedDate = expense.date;
    } else {
      // Use default currency if provided, otherwise first currency
      _selectedCurrency = widget.defaultCurrency ?? widget.availableCurrencies.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseToEdit != null ? 'Edit Expense' : 'Add Expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Amount input with scan button
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    textInputAction: TextInputAction.next,
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _openReceiptScanner,
                  tooltip: 'Scan receipt',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Currency selector
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              items: widget.availableCurrencies
                  .map((currency) => DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCurrency = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Category selector
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: Categories.allCategories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Text(Categories.getIcon(category)),
                            const SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Date picker
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Note input
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add a note...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveExpense(),
            ),
            const SizedBox(height: 24),

            // Bottom save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveExpense,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(widget.expenseToEdit != null ? 'Update Expense' : 'Save Expense'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final note = _noteController.text.trim();

      if (widget.expenseToEdit != null) {
        // Update existing expense
        final updatedExpense = widget.expenseToEdit!.copyWith(
          amount: amount,
          currency: _selectedCurrency!,
          category: _selectedCategory,
          date: _selectedDate,
          note: note.isEmpty ? null : note,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        await _personalExpenseDao.updateExpense(updatedExpense);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new expense
        final expense = PersonalExpense(
          amount: amount,
          currency: _selectedCurrency!,
          category: _selectedCategory,
          date: _selectedDate,
          note: note.isEmpty ? null : note,
        );

        await _personalExpenseDao.insertExpense(expense);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
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

  Future<void> _openReceiptScanner() async {
    final result = await Navigator.push<ReceiptData>(
      context,
      MaterialPageRoute(
        builder: (context) => const ReceiptCaptureScreen(),
      ),
    );

    if (result != null && mounted) {
      // Show preview dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ReceiptPreviewDialog(data: result),
      );

      if (confirmed == true && mounted) {
        _applyReceiptData(result);
      }
    }
  }

  void _applyReceiptData(ReceiptData data) {
    setState(() {
      if (data.amount != null) {
        _amountController.text = data.amount!.toStringAsFixed(2);
      }

      if (data.currency != null && widget.availableCurrencies.contains(data.currency)) {
        _selectedCurrency = data.currency;
      }

      if (data.category != null && Categories.allCategories.contains(data.category)) {
        _selectedCategory = data.category!;
      }

      if (data.date != null) {
        _selectedDate = _parseDate(data.date!);
      }

      if (data.storeName != null) {
        _noteController.text = data.storeName!;
      }
    });
  }

  DateTime _parseDate(String dateStr) {
    // Try to parse various date formats
    try {
      // Try ISO format first (YYYY-MM-DD)
      if (dateStr.contains('-') && dateStr.length >= 8) {
        return DateTime.parse(dateStr);
      }

      // Try MM/DD/YYYY or DD/MM/YYYY
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          // Assume MM/DD/YYYY for US-style
          final month = int.tryParse(parts[0]);
          final day = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (month != null && day != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }

      // Try DD.MM.YYYY
      if (dateStr.contains('.')) {
        final parts = dateStr.split('.');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
    } catch (e) {
      // If parsing fails, return current date
    }

    // Default: return current date if parsing fails
    return DateTime.now();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/group_expense.dart';
import '../models/personal_expense.dart';
import '../models/user.dart';
import '../models/enums.dart';
import '../models/categories.dart';
import '../models/receipt_data.dart';
import '../database/dao/group_expense_dao.dart';
import '../database/dao/personal_expense_dao.dart';
import '../database/dao/user_dao.dart';
import '../widgets/receipt_preview_dialog.dart';
import 'receipt_capture_screen.dart';

/// Screen for adding or editing a group expense
class AddGroupExpenseScreen extends StatefulWidget {
  final Group group;
  final List<Member> members;
  final GroupExpense? expenseToEdit;

  const AddGroupExpenseScreen({
    super.key,
    required this.group,
    required this.members,
    this.expenseToEdit,
  });

  @override
  State<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends State<AddGroupExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _expenseDao = GroupExpenseDao();
  final _personalExpenseDao = PersonalExpenseDao();
  final _userDao = UserDao();

  String? _selectedCurrency;
  String _selectedCategory = Categories.food;
  DateTime _selectedDate = DateTime.now();
  Member? _paidBy;
  List<Member> _splitBetween = [];
  SplitType _splitType = SplitType.equal;
  Map<String, double> _splitDetails = {}; // memberId -> amount or percentage
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
      _paidBy = widget.members.firstWhere((m) => m.id == expense.paidBy);
      _splitBetween = widget.members
          .where((m) => expense.splitBetween.contains(m.id))
          .toList();
      _splitType = expense.splitType;
      _splitDetails = expense.splitDetails ?? {};
    } else {
      _selectedCurrency = widget.group.defaultCurrency;
      // Default: first member pays, split among all members
      if (widget.members.isNotEmpty) {
        _paidBy = widget.members.first;
        _splitBetween = List.from(widget.members);
      }
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
    final isPersonalGroup = widget.group.isPersonal;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseToEdit != null
            ? 'Edit Expense'
            : (isPersonalGroup ? 'Add Personal Expense' : 'Add Group Expense')),
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
              items: widget.group.currencies
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

            // Hide split-related fields for personal groups
            if (!isPersonalGroup) ...[
              // Paid by selector
              DropdownButtonFormField<Member>(
                value: _paidBy,
                decoration: const InputDecoration(
                  labelText: 'Paid by',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: widget.members
                    .map((member) => DropdownMenuItem(
                          value: member,
                          child: Text(member.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _paidBy = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select who paid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Split between selector
              InkWell(
                onTap: _selectSplitMembers,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Split between',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  child: Text(
                    _splitBetween.isEmpty
                        ? 'Select members'
                        : '${_splitBetween.length} member${_splitBetween.length != 1 ? 's' : ''}: ${_splitBetween.map((m) => m.name).join(', ')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: _splitBetween.isEmpty ? Colors.grey : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Split type selector
              DropdownButtonFormField<SplitType>(
                value: _splitType,
                decoration: const InputDecoration(
                  labelText: 'Split Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SplitType.equal,
                    child: Text('Equal Split'),
                  ),
                  DropdownMenuItem(
                    value: SplitType.unequal,
                    child: Text('Unequal Split'),
                  ),
                  DropdownMenuItem(
                    value: SplitType.percentage,
                    child: Text('Percentage Split'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _splitType = value!;
                    _splitDetails.clear(); // Reset split details when type changes
                  });
                },
              ),
              const SizedBox(height: 16),

              // Configure split details button (for unequal and percentage)
              if (_splitType != SplitType.equal && _splitBetween.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _configureSplitDetails,
                  icon: const Icon(Icons.tune),
                  label: Text(
                    _splitType == SplitType.unequal
                        ? 'Configure Amounts'
                        : 'Configure Percentages',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              if (_splitType != SplitType.equal && _splitBetween.isNotEmpty)
                const SizedBox(height: 16),
            ],

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
            ),
            const SizedBox(height: 24),

            // Info card - only show for shared groups
            if (!isPersonalGroup)
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
                          _splitType == SplitType.equal
                              ? 'Equal Split'
                              : _splitType == SplitType.unequal
                                  ? 'Unequal Split'
                                  : 'Percentage Split',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._buildSplitInfo(),
                  ],
                ),
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

  List<Widget> _buildSplitInfo() {
    if (_splitBetween.isEmpty || _amountController.text.isEmpty) {
      return [];
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null) return [];

    switch (_splitType) {
      case SplitType.equal:
        final perPerson = amount / _splitBetween.length;
        return [
          Text(
            'Each person pays: ${perPerson.toStringAsFixed(2)} ${_selectedCurrency ?? ''}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ];

      case SplitType.unequal:
        if (_splitDetails.isEmpty) {
          return [
            Text(
              'Tap "Configure Amounts" to set custom amounts for each person',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ];
        }
        // Show breakdown
        return _splitBetween.map((member) {
          final memberAmount = _splitDetails[member.id] ?? 0.0;
          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${member.name}: ${memberAmount.toStringAsFixed(2)} ${_selectedCurrency ?? ''}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          );
        }).toList();

      case SplitType.percentage:
        if (_splitDetails.isEmpty) {
          return [
            Text(
              'Tap "Configure Percentages" to set percentages for each person',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ];
        }
        // Show breakdown
        return _splitBetween.map((member) {
          final percentage = _splitDetails[member.id] ?? 0.0;
          final memberAmount = amount * (percentage / 100);
          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${member.name}: ${percentage.toStringAsFixed(1)}% (${memberAmount.toStringAsFixed(2)} ${_selectedCurrency ?? ''})',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          );
        }).toList();
    }
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

  Future<void> _selectSplitMembers() async {
    final selected = await showDialog<List<Member>>(
      context: context,
      builder: (context) => _SplitMembersDialog(
        members: widget.members,
        selectedMembers: _splitBetween,
      ),
    );

    if (selected != null) {
      setState(() {
        _splitBetween = selected;
        // Clear split details if members changed
        _splitDetails.clear();
      });
    }
  }

  Future<void> _configureSplitDetails() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_splitType == SplitType.unequal) {
      final result = await showDialog<Map<String, double>>(
        context: context,
        builder: (context) => _UnequalSplitDialog(
          members: _splitBetween,
          totalAmount: amount,
          currency: _selectedCurrency ?? '',
          initialSplits: _splitDetails,
        ),
      );

      if (result != null) {
        setState(() {
          _splitDetails = result;
        });
      }
    } else if (_splitType == SplitType.percentage) {
      final result = await showDialog<Map<String, double>>(
        context: context,
        builder: (context) => _PercentageSplitDialog(
          members: _splitBetween,
          initialPercentages: _splitDetails,
        ),
      );

      if (result != null) {
        setState(() {
          _splitDetails = result;
        });
      }
    }
  }

  /// Calculate the user's fair share of the expense
  double _calculateUserFairShare(double totalAmount, String username) {
    // Find user's member in this group by username
    final userMember = widget.members.firstWhere(
      (m) => m.name == username,
      orElse: () => widget.members.first, // Fallback to first member
    );

    // Check if user is in the split
    if (!_splitBetween.any((m) => m.id == userMember.id)) {
      return 0.0; // User is not part of the split
    }

    switch (_splitType) {
      case SplitType.equal:
        return totalAmount / _splitBetween.length;

      case SplitType.unequal:
        return _splitDetails[userMember.id] ?? 0.0;

      case SplitType.percentage:
        final percentage = _splitDetails[userMember.id] ?? 0.0;
        return totalAmount * (percentage / 100);
    }
  }

  /// Create or update linked personal expense
  Future<void> _syncPersonalExpense({
    required GroupExpense groupExpense,
    required User user,
    bool isUpdate = false,
  }) async {
    // Calculate user's fair share
    final fairShare = _calculateUserFairShare(groupExpense.amount, user.username);

    // If fair share is 0, user is not part of the split, don't create personal expense
    if (fairShare == 0) {
      // If updating and personal expense exists, delete it
      if (isUpdate) {
        final existingExpenses = await _personalExpenseDao.getAllExpenses();
        final linkedExpense = existingExpenses.firstWhere(
          (e) => e.groupExpenseId == groupExpense.id,
          orElse: () => PersonalExpense(
            id: '',
            amount: 0,
            currency: '',
            category: '',
            date: DateTime.now(),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
        if (linkedExpense.id.isNotEmpty) {
          await _personalExpenseDao.deleteExpense(linkedExpense.id);
        }
      }
      return;
    }

    if (isUpdate) {
      // Find existing personal expense linked to this group expense
      final existingExpenses = await _personalExpenseDao.getAllExpenses();
      final linkedExpense = existingExpenses.firstWhere(
        (e) => e.groupExpenseId == groupExpense.id,
        orElse: () => PersonalExpense(
          id: '',
          amount: 0,
          currency: '',
          category: '',
          date: DateTime.now(),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

      if (linkedExpense.id.isNotEmpty) {
        // Update existing personal expense
        final updatedPersonalExpense = linkedExpense.copyWith(
          amount: fairShare,
          currency: groupExpense.currency,
          category: groupExpense.category,
          date: groupExpense.date,
          note: groupExpense.note,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _personalExpenseDao.updateExpense(updatedPersonalExpense);
      } else {
        // Create new personal expense if it doesn't exist
        final personalExpense = PersonalExpense(
          id: const Uuid().v4(),
          amount: fairShare,
          currency: groupExpense.currency,
          category: groupExpense.category,
          date: groupExpense.date,
          note: groupExpense.note,
          groupExpenseId: groupExpense.id,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _personalExpenseDao.insertExpense(personalExpense);
      }
    } else {
      // Create new personal expense
      final personalExpense = PersonalExpense(
        id: const Uuid().v4(),
        amount: fairShare,
        currency: groupExpense.currency,
        category: groupExpense.category,
        date: groupExpense.date,
        note: groupExpense.note,
        groupExpenseId: groupExpense.id,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _personalExpenseDao.insertExpense(personalExpense);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_splitBetween.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member to split between'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate split details for non-equal splits
    if (_splitType != SplitType.equal && _splitDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _splitType == SplitType.unequal
                ? 'Please configure amounts for each member'
                : 'Please configure percentages for each member',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final note = _noteController.text.trim();

      // Get current user
      final user = await _userDao.getUser();
      if (user == null) {
        throw Exception('User not found');
      }

      if (widget.expenseToEdit != null) {
        // Update existing expense
        final updatedExpense = widget.expenseToEdit!.copyWith(
          amount: amount,
          currency: _selectedCurrency!,
          category: _selectedCategory,
          date: _selectedDate,
          note: note.isEmpty ? null : note,
          paidBy: _paidBy!.id,
          splitBetween: _splitBetween.map((m) => m.id).toList(),
          splitType: _splitType,
          splitDetails: _splitType == SplitType.equal ? null : _splitDetails,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        await _expenseDao.updateExpense(updatedExpense);

        // Sync personal expense (update) - only for non-personal groups
        if (!widget.group.isPersonal) {
          await _syncPersonalExpense(
            groupExpense: updatedExpense,
            user: user,
            isUpdate: true,
          );
        }

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
        final uuid = const Uuid();
        final expense = GroupExpense(
          id: uuid.v4(),
          groupId: widget.group.id,
          amount: amount,
          currency: _selectedCurrency!,
          category: _selectedCategory,
          date: _selectedDate,
          note: note.isEmpty ? null : note,
          paidBy: _paidBy!.id,
          splitBetween: _splitBetween.map((m) => m.id).toList(),
          splitType: _splitType,
          splitDetails: _splitType == SplitType.equal ? null : _splitDetails,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deviceId: 'device_${DateTime.now().millisecondsSinceEpoch}',
          isSettled: false,
        );

        await _expenseDao.insertExpense(expense);

        // Sync personal expense (create) - only for non-personal groups
        if (!widget.group.isPersonal) {
          try {
            await _syncPersonalExpense(
              groupExpense: expense,
              user: user,
              isUpdate: false,
            );
            debugPrint('Personal expense synced for user ${user.username}, amount: ${_calculateUserFairShare(expense.amount, user.username)}');
          } catch (e) {
            debugPrint('Error syncing personal expense: $e');
            // Continue even if personal expense sync fails
          }
        }

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
      debugPrint('Error saving group expense: $e');
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

      if (data.currency != null && widget.group.currencies.contains(data.currency)) {
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

/// Dialog for selecting members to split expense between
class _SplitMembersDialog extends StatefulWidget {
  final List<Member> members;
  final List<Member> selectedMembers;

  const _SplitMembersDialog({
    required this.members,
    required this.selectedMembers,
  });

  @override
  State<_SplitMembersDialog> createState() => _SplitMembersDialogState();
}

class _SplitMembersDialogState extends State<_SplitMembersDialog> {
  late List<Member> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedMembers);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Split between'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.members.length,
          itemBuilder: (context, index) {
            final member = widget.members[index];
            final isSelected = _selected.any((m) => m.id == member.id);

            return CheckboxListTile(
              title: Text(member.name),
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(member);
                  } else {
                    _selected.removeWhere((m) => m.id == member.id);
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
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected),
          child: Text('Select (${_selected.length})'),
        ),
      ],
    );
  }
}

/// Dialog for configuring unequal split amounts
class _UnequalSplitDialog extends StatefulWidget {
  final List<Member> members;
  final double totalAmount;
  final String currency;
  final Map<String, double> initialSplits;

  const _UnequalSplitDialog({
    required this.members,
    required this.totalAmount,
    required this.currency,
    required this.initialSplits,
  });

  @override
  State<_UnequalSplitDialog> createState() => _UnequalSplitDialogState();
}

class _UnequalSplitDialogState extends State<_UnequalSplitDialog> {
  late Map<String, TextEditingController> _controllers;
  double _currentTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (var member in widget.members) {
      final initial = widget.initialSplits[member.id] ?? 0.0;
      _controllers[member.id] = TextEditingController(
        text: initial > 0 ? initial.toStringAsFixed(2) : '',
      );
      _controllers[member.id]!.addListener(_updateTotal);
    }
    _updateTotal();
  }

  void _updateTotal() {
    double total = 0.0;
    for (var controller in _controllers.values) {
      final value = double.tryParse(controller.text);
      if (value != null) {
        total += value;
      }
    }
    setState(() {
      _currentTotal = total;
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = (_currentTotal - widget.totalAmount).abs() < 0.01;

    return AlertDialog(
      title: const Text('Unequal Split'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: ${widget.totalAmount.toStringAsFixed(2)} ${widget.currency}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Allocated: ${_currentTotal.toStringAsFixed(2)} ${widget.currency}',
              style: TextStyle(
                color: isValid ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.members.length,
                itemBuilder: (context, index) {
                  final member = widget.members[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _controllers[member.id],
                      decoration: InputDecoration(
                        labelText: member.name,
                        border: const OutlineInputBorder(),
                        suffixText: widget.currency,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !isValid
              ? null
              : () {
                  final splits = <String, double>{};
                  for (var entry in _controllers.entries) {
                    final value = double.tryParse(entry.value.text);
                    if (value != null && value > 0) {
                      splits[entry.key] = value;
                    }
                  }
                  Navigator.pop(context, splits);
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Dialog for configuring percentage split
class _PercentageSplitDialog extends StatefulWidget {
  final List<Member> members;
  final Map<String, double> initialPercentages;

  const _PercentageSplitDialog({
    required this.members,
    required this.initialPercentages,
  });

  @override
  State<_PercentageSplitDialog> createState() => _PercentageSplitDialogState();
}

class _PercentageSplitDialogState extends State<_PercentageSplitDialog> {
  late Map<String, TextEditingController> _controllers;
  double _currentTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (var member in widget.members) {
      final initial = widget.initialPercentages[member.id] ?? 0.0;
      _controllers[member.id] = TextEditingController(
        text: initial > 0 ? initial.toStringAsFixed(1) : '',
      );
      _controllers[member.id]!.addListener(_updateTotal);
    }
    _updateTotal();
  }

  void _updateTotal() {
    double total = 0.0;
    for (var controller in _controllers.values) {
      final value = double.tryParse(controller.text);
      if (value != null) {
        total += value;
      }
    }
    setState(() {
      _currentTotal = total;
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = (_currentTotal - 100).abs() < 0.1;

    return AlertDialog(
      title: const Text('Percentage Split'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: ${_currentTotal.toStringAsFixed(1)}%',
              style: TextStyle(
                color: isValid ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isValid)
              Text(
                'Must add up to 100%',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.members.length,
                itemBuilder: (context, index) {
                  final member = widget.members[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _controllers[member.id],
                      decoration: InputDecoration(
                        labelText: member.name,
                        border: const OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !isValid
              ? null
              : () {
                  final percentages = <String, double>{};
                  for (var entry in _controllers.entries) {
                    final value = double.tryParse(entry.value.text);
                    if (value != null && value > 0) {
                      percentages[entry.key] = value;
                    }
                  }
                  Navigator.pop(context, percentages);
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

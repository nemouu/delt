import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/settlement.dart';
import '../database/dao/settlement_dao.dart';

/// Screen for recording a settlement (payment between members)
class RecordSettlementScreen extends StatefulWidget {
  final Group group;
  final List<Member> members;
  final Member? fromMember; // Pre-select payer if provided
  final Member? toMember; // Pre-select payee if provided

  const RecordSettlementScreen({
    super.key,
    required this.group,
    required this.members,
    this.fromMember,
    this.toMember,
  });

  @override
  State<RecordSettlementScreen> createState() => _RecordSettlementScreenState();
}

class _RecordSettlementScreenState extends State<RecordSettlementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _settlementDao = SettlementDao();

  Member? _payer; // Who is paying
  Member? _payee; // Who is receiving payment
  String? _selectedCurrency;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.group.currencies.first;
    _payer = widget.fromMember;
    _payee = widget.toMember;
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
        title: const Text('Record Settlement'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _recordSettlement,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
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
                        'What is a Settlement?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Record when one member pays another to settle debts. This helps keep track of who has paid whom back.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payer selector
            DropdownButtonFormField<Member>(
              value: _payer,
              decoration: const InputDecoration(
                labelText: 'From (Payer)',
                hintText: 'Who is paying?',
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
                  _payer = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select who is paying';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Arrow indicator
            Center(
              child: Icon(
                Icons.arrow_downward,
                size: 32,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),

            // Payee selector
            DropdownButtonFormField<Member>(
              value: _payee,
              decoration: const InputDecoration(
                labelText: 'To (Payee)',
                hintText: 'Who is receiving?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: widget.members
                  .map((member) => DropdownMenuItem(
                        value: member,
                        child: Text(member.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _payee = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select who is receiving payment';
                }
                if (_payer != null && value.id == _payer!.id) {
                  return 'Payer and payee must be different';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Amount input
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              textInputAction: TextInputAction.next,
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
                hintText: 'e.g., Cash payment, bank transfer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
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

  Future<void> _recordSettlement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final note = _noteController.text.trim();
      final uuid = const Uuid();

      final settlement = Settlement(
        id: uuid.v4(),
        groupId: widget.group.id,
        payerId: _payer!.id,
        payeeId: _payee!.id,
        amount: amount,
        currency: _selectedCurrency!,
        date: _selectedDate,
        note: note.isEmpty ? null : note,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        deviceId: 'device_${DateTime.now().millisecondsSinceEpoch}',
      );

      await _settlementDao.insertSettlement(settlement);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_payer!.name} paid ${_payee!.name} ${amount.toStringAsFixed(2)} ${_selectedCurrency!}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording settlement: $e'),
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
}

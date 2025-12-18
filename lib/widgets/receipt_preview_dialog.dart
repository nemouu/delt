import 'package:flutter/material.dart';
import '../models/receipt_data.dart';

/// Dialog for previewing extracted receipt data before applying to form
class ReceiptPreviewDialog extends StatefulWidget {
  final ReceiptData data;

  const ReceiptPreviewDialog({
    super.key,
    required this.data,
  });

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  bool _showRawText = false;

  @override
  Widget build(BuildContext context) {
    final hasAnyData = widget.data.hasAnyData;

    return AlertDialog(
      title: const Text('Receipt Data'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show message if no data extracted
            if (!hasAnyData) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No data could be extracted. Please enter manually.',
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Extracted fields
            if (widget.data.amount != null) _buildDataRow(
              icon: Icons.attach_money,
              label: 'Amount',
              value: '${widget.data.amount!.toStringAsFixed(2)} ${widget.data.currency ?? ''}',
              isExtracted: true,
            ),
            if (widget.data.currency != null && widget.data.amount == null) _buildDataRow(
              icon: Icons.currency_exchange,
              label: 'Currency',
              value: widget.data.currency!,
              isExtracted: true,
            ),
            if (widget.data.date != null) _buildDataRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: widget.data.date!,
              isExtracted: true,
            ),
            if (widget.data.category != null) _buildDataRow(
              icon: Icons.category,
              label: 'Category',
              value: widget.data.category!,
              isExtracted: true,
            ),
            if (widget.data.storeName != null) _buildDataRow(
              icon: Icons.store,
              label: 'Store',
              value: widget.data.storeName!,
              isExtracted: true,
            ),

            // Show missing fields
            if (widget.data.amount == null) _buildDataRow(
              icon: Icons.attach_money,
              label: 'Amount',
              value: 'Not detected',
              isExtracted: false,
            ),
            if (widget.data.date == null) _buildDataRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: 'Not detected',
              isExtracted: false,
            ),
            if (widget.data.category == null) _buildDataRow(
              icon: Icons.category,
              label: 'Category',
              value: 'Not detected',
              isExtracted: false,
            ),

            const Divider(height: 32),

            // Raw OCR text section
            InkWell(
              onTap: () {
                setState(() {
                  _showRawText = !_showRawText;
                });
              },
              child: Row(
                children: [
                  Icon(
                    _showRawText ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Raw OCR Text',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),

            if (_showRawText) ...[
              const SizedBox(height: 12),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.data.rawText.isEmpty
                        ? 'No text detected'
                        : widget.data.rawText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isExtracted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isExtracted ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isExtracted ? Colors.black87 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          if (isExtracted)
            const Icon(
              Icons.check_circle,
              size: 20,
              color: Colors.green,
            ),
        ],
      ),
    );
  }
}

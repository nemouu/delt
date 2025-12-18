import 'package:flutter/material.dart';
import '../models/categories.dart';

/// Reusable expense list item widget
class ExpenseListItem extends StatelessWidget {
  final String amount;
  final String currency;
  final String category;
  final String? note;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;

  const ExpenseListItem({
    super.key,
    required this.amount,
    required this.currency,
    required this.category,
    this.note,
    this.subtitle,
    this.onTap,
    this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            Categories.getIcon(category),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          '$amount $currency',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(
                note!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: onMorePressed != null
            ? IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onMorePressed,
              )
            : null,
      ),
    );
  }
}

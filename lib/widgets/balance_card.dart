import 'package:flutter/material.dart';
import '../models/member.dart';
import '../services/balance_calculator.dart';
import '../utils/color_utils.dart';

/// Reusable balance card widget
class BalanceCard extends StatelessWidget {
  final Member member;
  final MemberBalance balance;
  final VoidCallback? onTap;

  const BalanceCard({
    super.key,
    required this.member,
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.parseHexColor(member.colorHex);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: ColorUtils.withOpacity(color, 0.2),
          child: Text(
            member.name[0].toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(balance.memberName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Paid: ${balance.totalPaid.toStringAsFixed(2)}'),
            Text('Fair share: ${balance.fairShare.toStringAsFixed(2)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              balance.balance >= 0 ? 'Gets back' : 'Owes',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              balance.balance.abs().toStringAsFixed(2),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: balance.balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

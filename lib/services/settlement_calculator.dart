import 'balance_calculator.dart';

/// A suggested settlement transaction
class SettlementTransaction {
  final String payerId; // Who should pay
  final String payerName;
  final String payeeId; // Who should receive
  final String payeeName;
  final double amount;

  SettlementTransaction({
    required this.payerId,
    required this.payerName,
    required this.payeeId,
    required this.payeeName,
    required this.amount,
  });

  @override
  String toString() {
    return '$payerName pays $payeeName: \$${amount.toStringAsFixed(2)}';
  }
}

/// Calculates optimal settlement transactions to minimize number of payments
class SettlementCalculator {
  /// Calculate optimal settlements using greedy algorithm
  ///
  /// This minimizes the number of transactions needed to settle all debts
  static List<SettlementTransaction> calculateOptimalSettlements(
    Map<String, MemberBalance> balances,
  ) {
    // Separate into debtors (owe money) and creditors (are owed money)
    final List<_BalanceEntry> debtors = [];
    final List<_BalanceEntry> creditors = [];

    for (var entry in balances.entries) {
      final balance = entry.value;

      if (balance.balance < -0.01) {
        // Owes money (negative balance)
        debtors.add(_BalanceEntry(
          memberId: balance.memberId,
          memberName: balance.memberName,
          amount: -balance.balance, // Make positive
        ));
      } else if (balance.balance > 0.01) {
        // Is owed money (positive balance)
        creditors.add(_BalanceEntry(
          memberId: balance.memberId,
          memberName: balance.memberName,
          amount: balance.balance,
        ));
      }
    }

    // Sort by amount (largest first) for better optimization
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    // Generate settlements
    final List<SettlementTransaction> settlements = [];
    int debtorIndex = 0;
    int creditorIndex = 0;

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      // Settle the smaller of the two amounts
      final settlementAmount = debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount;

      settlements.add(SettlementTransaction(
        payerId: debtor.memberId,
        payerName: debtor.memberName,
        payeeId: creditor.memberId,
        payeeName: creditor.memberName,
        amount: settlementAmount,
      ));

      // Update remaining amounts
      debtor.amount -= settlementAmount;
      creditor.amount -= settlementAmount;

      // Move to next debtor/creditor if fully settled
      if (debtor.amount < 0.01) {
        debtorIndex++;
      }
      if (creditor.amount < 0.01) {
        creditorIndex++;
      }
    }

    return settlements;
  }

  /// Calculate simple pairwise settlements (not optimized)
  ///
  /// Each person who owes money pays each person they owe directly
  /// Results in more transactions but simpler to understand
  static List<SettlementTransaction> calculateSimpleSettlements(
    Map<String, MemberBalance> balances,
  ) {
    final settlements = <SettlementTransaction>[];

    // For each debtor, calculate how much they owe to each creditor
    // based on the ratio of what each creditor is owed
    final debtors = balances.values.where((b) => b.owes).toList();
    final creditors = balances.values.where((b) => b.isOwed).toList();

    if (creditors.isEmpty) return settlements;

    final totalOwed = creditors.fold(0.0, (sum, c) => sum + c.balance);

    for (var debtor in debtors) {
      final debtAmount = -debtor.balance; // Make positive

      for (var creditor in creditors) {
        // Calculate proportional amount
        final proportion = creditor.balance / totalOwed;
        final amount = debtAmount * proportion;

        if (amount > 0.01) {
          // Only add if more than 1 cent
          settlements.add(SettlementTransaction(
            payerId: debtor.memberId,
            payerName: debtor.memberName,
            payeeId: creditor.memberId,
            payeeName: creditor.memberName,
            amount: amount,
          ));
        }
      }
    }

    return settlements;
  }
}

/// Internal helper class for settlement calculation
class _BalanceEntry {
  final String memberId;
  final String memberName;
  double amount; // Mutable for algorithm

  _BalanceEntry({
    required this.memberId,
    required this.memberName,
    required this.amount,
  });
}

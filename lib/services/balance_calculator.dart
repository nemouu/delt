import '../models/group_expense.dart';
import '../models/member.dart';
import '../utils/constants.dart';

/// Balance information for a member
class MemberBalance {
  final String memberId;
  final String memberName;
  final double totalPaid; // Total amount paid by this member
  final double fairShare; // What they should have paid (equal split)
  final double balance; // Net balance (positive = owed, negative = owes)

  MemberBalance({
    required this.memberId,
    required this.memberName,
    required this.totalPaid,
    required this.fairShare,
    required this.balance,
  });

  bool get owes => balance < 0;
  bool get isOwed => balance > 0;
  bool get isSettled => balance.abs() < AppConstants.balanceThreshold;

  @override
  String toString() {
    return 'MemberBalance($memberName: paid=$totalPaid, share=$fairShare, balance=$balance)';
  }
}

/// Calculates balances for group expenses
class BalanceCalculator {
  /// Calculate balances for all members in a group
  ///
  /// Returns a map of member ID to MemberBalance
  static Map<String, MemberBalance> calculateBalances(
    List<Member> members,
    List<GroupExpense> expenses,
  ) {
    // Initialize balances
    final Map<String, double> totalPaid = {};
    final Map<String, double> totalOwed = {};

    for (var member in members) {
      totalPaid[member.id] = 0.0;
      totalOwed[member.id] = 0.0;
    }

    // Calculate totals
    for (var expense in expenses) {
      // Add to payer's total paid
      totalPaid[expense.paidBy] =
          (totalPaid[expense.paidBy] ?? 0.0) + expense.amount;

      // Split amount evenly among splitBetween members
      final splitAmount = expense.amount / expense.splitBetween.length;

      for (var memberId in expense.splitBetween) {
        totalOwed[memberId] = (totalOwed[memberId] ?? 0.0) + splitAmount;
      }
    }

    // Calculate net balances
    final Map<String, MemberBalance> balances = {};

    for (var member in members) {
      final paid = totalPaid[member.id] ?? 0.0;
      final owed = totalOwed[member.id] ?? 0.0;
      final balance = paid - owed; // Positive = owed money, negative = owes money

      balances[member.id] = MemberBalance(
        memberId: member.id,
        memberName: member.name,
        totalPaid: paid,
        fairShare: owed,
        balance: balance,
      );
    }

    return balances;
  }

  /// Get total group spending
  static double getTotalSpending(List<GroupExpense> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Get spending by category
  static Map<String, double> getSpendingByCategory(
    List<GroupExpense> expenses,
  ) {
    final Map<String, double> categoryTotals = {};

    for (var expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    return categoryTotals;
  }

  /// Check if group is fully settled (all balances near zero)
  static bool isGroupSettled(Map<String, MemberBalance> balances) {
    return balances.values.every((balance) => balance.isSettled);
  }
}

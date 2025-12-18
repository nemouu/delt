import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/group_expense.dart';
import '../models/personal_expense.dart';
import '../models/categories.dart';
import '../database/dao/group_dao.dart';
import '../database/dao/member_dao.dart';
import '../database/dao/group_expense_dao.dart';
import '../database/dao/personal_expense_dao.dart';
import '../services/balance_calculator.dart';
import '../services/settlement_calculator.dart';
import '../utils/color_utils.dart';
import 'add_group_expense_screen.dart';
import 'add_member_screen.dart';
import 'group_qr_screen.dart';
import 'group_settings_screen.dart';
import 'record_settlement_screen.dart';

/// Group details screen with tabs for expenses, members, and balances
class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with TickerProviderStateMixin {
  final _groupDao = GroupDao();
  final _memberDao = MemberDao();
  final _expenseDao = GroupExpenseDao();
  final _personalExpenseDao = PersonalExpenseDao();

  Group? _group;
  List<Member> _members = [];
  List<GroupExpense> _expenses = [];
  List<PersonalExpense> _personalExpenses = []; // For personal group only
  Map<String, MemberBalance> _balances = {};
  bool _isLoading = true;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  void _initTabController() {
    final tabCount = _group?.isPersonal == true ? 1 : 3;

    // Dispose existing controller if tab count changed
    if (_tabController != null && _tabController!.length != tabCount) {
      _tabController!.dispose();
      _tabController = null;
    }

    // Create new controller only if needed
    if (_tabController == null) {
      _tabController = TabController(length: tabCount, vsync: this);
      // Add listener to rebuild FAB when tab changes
      _tabController!.addListener(() {
        if (mounted) {
          setState(() {
            // Rebuild to update FAB
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final group = await _groupDao.getGroupById(widget.groupId);
      final members = await _memberDao.getMembersByGroupId(widget.groupId);
      final expenses = await _expenseDao.getExpensesByGroupId(widget.groupId);

      // For personal groups, also load linked personal expenses (from group expenses)
      List<PersonalExpense> personalExpenses = [];
      if (group?.isPersonal == true) {
        final allPersonalExpenses = await _personalExpenseDao.getAllExpenses();
        // Get only expenses linked to group expenses (not pure personal expenses)
        personalExpenses = allPersonalExpenses
            .where((e) => e.groupExpenseId != null)
            .toList();
      }

      // Calculate balances
      final balances = BalanceCalculator.calculateBalances(members, expenses);

      setState(() {
        _group = group;
        _members = members;
        _expenses = expenses;
        _personalExpenses = personalExpenses;
        _balances = balances;
        _isLoading = false;
      });

      // Initialize tab controller after group is loaded
      _initTabController();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Group Not Found'),
        ),
        body: const Center(
          child: Text('Group not found'),
        ),
      );
    }

    final isPersonal = _group!.isPersonal;

    return Scaffold(
      appBar: AppBar(
        title: Text(_group!.name),
        actions: [
          if (!isPersonal)
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Share via QR Code',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupQRScreen(groupId: _group!.id),
                  ),
                );
              },
            ),
          if (!isPersonal)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Group Settings',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupSettingsScreen(groupId: _group!.id),
                  ),
                );

                // If group was deleted, pop back to groups list
                if (!mounted) return;
                if (result == true) {
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context, true);
                } else {
                  // Otherwise just reload data in case group was updated
                  _loadGroupData();
                }
              },
            ),
        ],
      ),
      body: isPersonal || _tabController == null
          ? _buildExpensesTab()
          : TabBarView(
              controller: _tabController!,
              children: [
                _buildExpensesTab(),
                _buildBalancesTab(),
                _buildMembersTab(),
              ],
            ),
      bottomNavigationBar: isPersonal || _tabController == null
          ? null
          : NavigationBar(
              selectedIndex: _tabController!.index,
              onDestinationSelected: (index) {
                setState(() {
                  _tabController!.animateTo(index);
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Expenses',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  selectedIcon: Icon(Icons.account_balance),
                  label: 'Balances',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Members',
                ),
              ],
            ),
      floatingActionButton: _buildContextualFAB(isPersonal),
    );
  }

  Widget? _buildContextualFAB(bool isPersonal) {
    // For personal groups, always show add expense button
    if (isPersonal) {
      return FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add),
      );
    }

    // For regular groups, show button based on current tab
    if (_tabController == null) return null;

    final currentIndex = _tabController!.index;

    if (currentIndex == 0) {
      // Expenses tab - show add expense button
      return FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add),
      );
    } else if (currentIndex == 1) {
      // Balances tab - no FAB
      return null;
    } else if (currentIndex == 2) {
      // Members tab - show add member button
      return FloatingActionButton(
        onPressed: _addMember,
        child: const Icon(Icons.person_add),
      );
    }

    return null;
  }

  /// Calculate sums for different time periods, grouped by currency
  Map<String, Map<String, double>> _calculateSums() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    final Map<String, double> weeklySums = {};
    final Map<String, double> monthlySums = {};
    final Map<String, double> yearlySums = {};

    // Process group expenses
    for (var expense in _expenses) {
      final expenseDate = DateTime(expense.date.year, expense.date.month, expense.date.day);

      // Weekly sum (this week)
      if (expenseDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          expenseDate.isBefore(today.add(const Duration(days: 1)))) {
        weeklySums[expense.currency] = (weeklySums[expense.currency] ?? 0) + expense.amount;
      }

      // Monthly sum (this month)
      if (expenseDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          expenseDate.isBefore(today.add(const Duration(days: 1)))) {
        monthlySums[expense.currency] = (monthlySums[expense.currency] ?? 0) + expense.amount;
      }

      // Yearly sum (this year)
      if (expenseDate.isAfter(yearStart.subtract(const Duration(days: 1))) &&
          expenseDate.isBefore(today.add(const Duration(days: 1)))) {
        yearlySums[expense.currency] = (yearlySums[expense.currency] ?? 0) + expense.amount;
      }
    }

    // For personal groups, also include personal expenses
    if (_group?.isPersonal == true) {
      for (var expense in _personalExpenses) {
        final expenseDate = DateTime(expense.date.year, expense.date.month, expense.date.day);

        // Weekly sum (this week)
        if (expenseDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            expenseDate.isBefore(today.add(const Duration(days: 1)))) {
          weeklySums[expense.currency] = (weeklySums[expense.currency] ?? 0) + expense.amount;
        }

        // Monthly sum (this month)
        if (expenseDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            expenseDate.isBefore(today.add(const Duration(days: 1)))) {
          monthlySums[expense.currency] = (monthlySums[expense.currency] ?? 0) + expense.amount;
        }

        // Yearly sum (this year)
        if (expenseDate.isAfter(yearStart.subtract(const Duration(days: 1))) &&
            expenseDate.isBefore(today.add(const Duration(days: 1)))) {
          yearlySums[expense.currency] = (yearlySums[expense.currency] ?? 0) + expense.amount;
        }
      }
    }

    return {
      'weekly': weeklySums,
      'monthly': monthlySums,
      'yearly': yearlySums,
    };
  }

  /// Build sum display card
  Widget _buildSumCard(String label, Map<String, double> sums, IconData icon, Color color) {
    if (sums.isEmpty) {
      return Container();
    }

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              ...sums.entries.map((entry) => Text(
                '${entry.value.toStringAsFixed(2)} ${entry.key}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesTab() {
    final isPersonalGroup = _group?.isPersonal ?? false;
    final hasAnyExpenses = _expenses.isNotEmpty || (isPersonalGroup && _personalExpenses.isNotEmpty);

    if (!hasAnyExpenses) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add the first expense',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Calculate sums
    final sums = _calculateSums();
    final weeklySums = sums['weekly']!;
    final monthlySums = sums['monthly']!;
    final yearlySums = sums['yearly']!;

    // Group expenses by date
    final Map<String, List<dynamic>> groupedExpenses = {};

    // Add group expenses
    for (var expense in _expenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
      groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
    }

    // For personal groups, also add linked personal expenses
    if (isPersonalGroup) {
      for (var expense in _personalExpenses) {
        final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
        groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
      }
    }

    // Sort date keys in descending order
    final sortedDateKeys = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      children: [
        // Sum cards at the top
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildSumCard('This Week', weeklySums, Icons.calendar_view_week, Colors.green),
              const SizedBox(width: 8),
              _buildSumCard('This Month', monthlySums, Icons.calendar_month, Colors.blue),
              const SizedBox(width: 8),
              _buildSumCard('This Year', yearlySums, Icons.calendar_today, Colors.orange),
            ],
          ),
        ),
        // Expense list
        ...sortedDateKeys.map((dateKey) {
          final expenses = groupedExpenses[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  _formatDateHeader(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              // Expenses for this date
              ...expenses.map((expense) {
                if (expense is GroupExpense) {
                  return _buildExpenseCard(expense);
                } else if (expense is PersonalExpense) {
                  return _buildPersonalExpenseCard(expense);
                } else {
                  return const SizedBox.shrink();
                }
              }),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildExpenseCard(GroupExpense expense) {
    final paidByMember = _members.firstWhere((m) => m.id == expense.paidBy);
    final splitCount = expense.splitBetween.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            Categories.getIcon(expense.category),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.category),
            const SizedBox(height: 4),
            Text(
              'Paid by ${paidByMember.name}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Split among $splitCount member${splitCount != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (expense.note != null) ...[
              const SizedBox(height: 4),
              Text(
                expense.note!,
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
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _showExpenseOptions(expense);
          },
        ),
      ),
    );
  }

  Widget _buildPersonalExpenseCard(PersonalExpense expense) {
    // For linked group expenses, show which group it's from
    final isLinked = expense.groupExpenseId != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLinked
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            Categories.getIcon(expense.category),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                expense.category,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLinked)
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'From shared group',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            if (expense.note != null && expense.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                expense.note!,
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
        trailing: isLinked
            ? Icon(Icons.info_outline, color: Colors.grey[400])
            : null,
        onTap: isLinked
            ? () {
                // Show info that this is from a group expense
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Group Expense Share'),
                    content: const Text(
                        'This is your share of a group expense. To edit or delete it, modify the original group expense.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            : null,
      ),
    );
  }

  Widget _buildBalancesTab() {
    if (_balances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No balances yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add expenses to see balances',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final balancesList = _balances.values.toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    // Calculate settlement suggestions
    final settlements = SettlementCalculator.calculateOptimalSettlements(_balances);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Balances section
              ...balancesList.map((balance) {
                final member = _members.firstWhere((m) => m.id == balance.memberId);
                final color = _parseColor(member.colorHex);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
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
              }),

              // Settlement suggestions section
              if (settlements.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Settlement Suggestions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Optimized to minimize the number of transactions:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                ...settlements.map((settlement) {
                  final payer = _members.firstWhere((m) => m.id == settlement.payerId);
                  final payee = _members.firstWhere((m) => m.id == settlement.payeeId);
                  final payerColor = _parseColor(payer.colorHex);
                  final payeeColor = _parseColor(payee.colorHex);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.blue[50],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ColorUtils.withOpacity(payerColor, 0.2),
                        radius: 20,
                        child: Text(
                          payer.name[0].toUpperCase(),
                          style: TextStyle(
                            color: payerColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(settlement.payerName),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(settlement.payeeName),
                              ],
                            ),
                          ),
                          Text(
                            settlement.amount.toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text('${settlement.payerName} pays ${settlement.payeeName}'),
                      trailing: CircleAvatar(
                        backgroundColor: ColorUtils.withOpacity(payeeColor, 0.2),
                        radius: 20,
                        child: Text(
                          payee.name[0].toUpperCase(),
                          style: TextStyle(
                            color: payeeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        // Record Settlement button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(
            onPressed: _recordSettlement,
            icon: const Icon(Icons.payments),
            label: const Text('Record Settlement'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final color = _parseColor(member.colorHex);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
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
            title: Text(member.name),
            subtitle: Text(
              member.role.toString().split('.').last.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: member.role.toString().contains('admin')
                    ? Colors.orange
                    : Colors.grey[600],
                fontWeight: member.role.toString().contains('admin')
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            trailing: member.role.toString().contains('admin')
                ? const Icon(Icons.admin_panel_settings, color: Colors.orange)
                : null,
          ),
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return 'Today';
    } else if (expenseDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM dd, yyyy').format(date);
    }
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.substring(1), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.grey;
    }
  }

  Future<void> _addExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGroupExpenseScreen(
          group: _group!,
          members: _members,
        ),
      ),
    );

    // Reload group data if an expense was added
    if (result == true) {
      _loadGroupData();
    }
  }

  Future<void> _addMember() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemberScreen(groupId: _group!.id),
      ),
    );

    // Reload group data if a member was added
    if (result == true) {
      _loadGroupData();
    }
  }

  Future<void> _recordSettlement() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordSettlementScreen(
          group: _group!,
          members: _members,
        ),
      ),
    );

    // Reload group data if a settlement was recorded
    if (result == true) {
      _loadGroupData();
    }
  }

  void _showExpenseOptions(GroupExpense expense) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              _editExpense(expense);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteExpense(expense);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editExpense(GroupExpense expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGroupExpenseScreen(
          group: _group!,
          members: _members,
          expenseToEdit: expense,
        ),
      ),
    );

    // Reload group data if the expense was updated
    if (result == true) {
      _loadGroupData();
    }
  }

  Future<void> _deleteExpense(GroupExpense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Are you sure you want to delete this expense?\n\n${expense.amount.toStringAsFixed(2)} ${expense.currency} - ${expense.category}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete linked personal expense first
        final allPersonalExpenses = await _personalExpenseDao.getAllExpenses();
        final linkedExpense = allPersonalExpenses.firstWhere(
          (e) => e.groupExpenseId == expense.id,
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

        // Delete group expense
        await _expenseDao.deleteExpense(expense.id);
        _loadGroupData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

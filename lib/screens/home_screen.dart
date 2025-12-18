import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/personal_expense.dart';
import '../models/categories.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../database/dao/personal_expense_dao.dart';
import '../database/dao/user_dao.dart';
import '../database/dao/group_dao.dart';
import '../database/dao/member_dao.dart';
import 'add_personal_expense_screen.dart';
import 'create_group_screen.dart';
import 'group_details_screen.dart';
import 'scan_qr_screen.dart';
import 'change_pin_screen.dart';
import 'manage_currencies_screen.dart';

/// Home screen with bottom navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GroupsTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Personal expenses tab
class PersonalExpensesTab extends StatefulWidget {
  const PersonalExpensesTab({super.key});

  @override
  State<PersonalExpensesTab> createState() => _PersonalExpensesTabState();
}

class _PersonalExpensesTabState extends State<PersonalExpensesTab> {
  final _personalExpenseDao = PersonalExpenseDao();
  final _userDao = UserDao();
  List<PersonalExpense> _expenses = [];
  List<PersonalExpense> _filteredExpenses = [];
  User? _user;
  bool _isLoading = true;
  String? _filterCategory;
  DateTimeRange? _filterDateRange;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final expenses = await _personalExpenseDao.getAllExpenses();
      final user = await _userDao.getUser();

      setState(() {
        _expenses = expenses;
        _filteredExpenses = _applyFilters(expenses);
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading expenses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Expenses'),
        actions: [
          if (_expenses.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: _hasActiveFilters() ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: _showFilterDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? _buildEmptyState()
              : _filteredExpenses.isEmpty
                  ? _buildNoResultsState()
                  : _buildExpensesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            'Tap + to add your first expense',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No expenses match filters',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear),
            label: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList() {
    // Group expenses by date
    final Map<String, List<PersonalExpense>> groupedExpenses = {};
    for (var expense in _filteredExpenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
      groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
    }

    // Sort date keys in descending order
    final sortedDateKeys = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedDateKeys.length + 1, // +1 for summary card
      itemBuilder: (context, index) {
        // First item is the summary card
        if (index == 0) {
          return _buildPeriodSummary();
        }

        // Adjust index for expenses
        final expenseIndex = index - 1;
        final dateKey = sortedDateKeys[expenseIndex];
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
            ...expenses.map((expense) => _buildExpenseCard(expense)),
          ],
        );
      },
    );
  }

  Widget _buildPeriodSummary() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final currentYear = DateTime(now.year);

    // Calculate monthly totals by currency
    final Map<String, double> monthlyTotals = {};
    final Map<String, double> yearlyTotals = {};

    for (var expense in _filteredExpenses) {
      final expenseDate = DateTime(expense.date.year, expense.date.month);
      final expenseYear = DateTime(expense.date.year);

      // Monthly totals
      if (expenseDate == currentMonth) {
        monthlyTotals[expense.currency] =
            (monthlyTotals[expense.currency] ?? 0) + expense.amount;
      }

      // Yearly totals
      if (expenseYear == currentYear) {
        yearlyTotals[expense.currency] =
            (yearlyTotals[expense.currency] ?? 0) + expense.amount;
      }
    }

    // Don't show summary if no expenses this month
    if (monthlyTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Spending Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Monthly totals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(now),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: monthlyTotals.entries.map((entry) {
                    return Text(
                      '${entry.value.toStringAsFixed(2)} ${entry.key}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            // Yearly totals (only if different from monthly)
            if (yearlyTotals.keys.any((currency) =>
                (yearlyTotals[currency] ?? 0) !=
                (monthlyTotals[currency] ?? 0))) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Year ${now.year}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yearlyTotals.entries.map((entry) {
                      return Text(
                        '${entry.value.toStringAsFixed(2)} ${entry.key}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(PersonalExpense expense) {
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

  Future<void> _addExpense() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not found. Please restart the app.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPersonalExpenseScreen(
          availableCurrencies: _user!.currencies,
          defaultCurrency: _user!.defaultCurrency,
        ),
      ),
    );

    // Reload expenses if an expense was added
    if (result == true) {
      _loadExpenses();
    }
  }

  Future<void> _editExpense(PersonalExpense expense) async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not found. Please restart the app.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPersonalExpenseScreen(
          availableCurrencies: _user!.currencies,
          defaultCurrency: _user!.defaultCurrency,
          expenseToEdit: expense,
        ),
      ),
    );

    // Reload expenses if the expense was updated
    if (result == true) {
      _loadExpenses();
    }
  }

  void _showExpenseOptions(PersonalExpense expense) {
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

  Future<void> _deleteExpense(PersonalExpense expense) async {
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
        await _personalExpenseDao.deleteExpense(expense.id);
        _loadExpenses();
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

  List<PersonalExpense> _applyFilters(List<PersonalExpense> expenses) {
    var filtered = expenses;

    // Apply category filter
    if (_filterCategory != null) {
      filtered = filtered.where((e) => e.category == _filterCategory).toList();
    }

    // Apply date range filter
    if (_filterDateRange != null) {
      filtered = filtered.where((e) {
        final expenseDate = DateTime(e.date.year, e.date.month, e.date.day);
        final startDate = DateTime(_filterDateRange!.start.year,
            _filterDateRange!.start.month, _filterDateRange!.start.day);
        final endDate = DateTime(_filterDateRange!.end.year,
            _filterDateRange!.end.month, _filterDateRange!.end.day);
        return expenseDate.isAtSameMomentAs(startDate) ||
            expenseDate.isAtSameMomentAs(endDate) ||
            (expenseDate.isAfter(startDate) && expenseDate.isBefore(endDate));
      }).toList();
    }

    return filtered;
  }

  bool _hasActiveFilters() {
    return _filterCategory != null || _filterDateRange != null;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Expenses'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category filter
              const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _filterCategory,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ...Categories.allCategories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Text(Categories.getIcon(category)),
                            const SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      )),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    _filterCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Date range filter
              const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _filterDateRange,
                  );
                  if (picked != null) {
                    setDialogState(() {
                      _filterDateRange = picked;
                    });
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(
                  _filterDateRange == null
                      ? 'Select Date Range'
                      : '${DateFormat('MMM dd, yyyy').format(_filterDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_filterDateRange!.end)}',
                ),
              ),
              if (_filterDateRange != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      _filterDateRange = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Date Range'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _clearFilters();
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _filteredExpenses = _applyFilters(_expenses);
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _filterCategory = null;
      _filterDateRange = null;
      _filteredExpenses = _expenses;
    });
  }
}

/// Groups tab
class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  final _groupDao = GroupDao();
  final _memberDao = MemberDao();
  List<Group> _groups = [];
  Map<String, int> _memberCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await _groupDao.getAllGroups();
      final Map<String, int> counts = {};

      for (var group in groups) {
        final memberCount = await _memberDao.getMemberCount(group.id);
        counts[group.id] = memberCount;
      }

      // Sort: personal group first, then others alphabetically
      groups.sort((a, b) {
        if (a.isPersonal && !b.isPersonal) return -1;
        if (!a.isPersonal && b.isPersonal) return 1;
        return a.name.compareTo(b.name);
      });

      setState(() {
        _groups = groups;
        _memberCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading groups: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmptyState()
              : _buildGroupsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No groups yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a group to split expenses',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _joinGroup,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Join Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final memberCount = _memberCounts[group.id] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: group.isPersonal
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                group.isPersonal ? Icons.person : Icons.groups,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (group.isPersonal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Personal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (!group.isPersonal)
                  Text('$memberCount member${memberCount != 1 ? 's' : ''}'),
                if (!group.isPersonal) const SizedBox(height: 2),
                Text(
                  'Currencies: ${group.currencies.join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupDetailsScreen(groupId: group.id),
                ),
              );

              // Reload groups if group was modified or deleted
              if (result == true) {
                _loadGroups();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _createGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );

    // Reload groups if a group was created
    if (result == true) {
      _loadGroups();
    }
  }

  Future<void> _joinGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanQRScreen(),
      ),
    );

    // Reload groups if a group was joined
    if (result == true) {
      _loadGroups();
    }
  }
}

/// Settings tab (placeholder)
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change PIN'),
            subtitle: const Text('Update your security PIN'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePinScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Manage Currencies'),
            subtitle: const Text('Add or remove default currencies'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageCurrenciesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync'),
            subtitle: const Text('Sync with nearby devices'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync - Coming soon!')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Delt',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Privacy-first expense splitting app',
              );
            },
          ),
        ],
      ),
    );
  }
}

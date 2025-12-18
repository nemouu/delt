import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'database/database_helper.dart';
import 'database/dao/user_dao.dart';
import 'database/dao/group_dao.dart';
import 'database/dao/member_dao.dart';
import 'models/user.dart';
import 'models/group.dart';
import 'models/member.dart';
import 'models/enums.dart';
import 'services/security_manager.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/pin_unlock_screen.dart';
import 'screens/home_screen.dart';
import 'utils/constants.dart';

void main() {
  runApp(const DeltApp());
}

class DeltApp extends StatelessWidget {
  const DeltApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AppInitializer(),
    );
  }
}

/// App initializer - determines which screen to show
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  AppState _appState = AppState.loading;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _checkPinSetup();
  }

  Future<void> _checkPinSetup() async {
    final securityManager = SecurityManager();
    final isPinSetup = await securityManager.isPinSetup();

    setState(() {
      _appState = isPinSetup ? AppState.locked : AppState.setup;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_appState) {
      case AppState.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case AppState.setup:
        return PinSetupScreen(
          onPinSetup: _handlePinSetup,
        );

      case AppState.locked:
        return PinUnlockScreen(
          onUnlock: _handleUnlock,
          onUnlockFailed: _handleUnlockFailed,
          attemptsRemaining: AppConstants.maxLoginAttempts - _failedAttempts,
        );

      case AppState.unlocked:
        return const HomeScreen();
    }
  }

  Future<void> _handlePinSetup(String username, List<String> currencies, String defaultCurrency, String pin) async {
    final securityManager = SecurityManager();
    final success = await securityManager.setupPin(pin);

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to setup PIN. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Unlock and open database
    final passphrase = await securityManager.unlockWithPin(pin);
    if (passphrase == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unlock database. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Open database
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.openDatabase(passphrase);

    // Create user record
    final userDao = UserDao();
    final now = DateTime.now().millisecondsSinceEpoch;
    final user = User(
      id: 'user_$now',
      username: username,
      currencies: currencies,
      defaultCurrency: defaultCurrency,
      createdAt: now,
      updatedAt: now,
    );
    await userDao.insertUser(user);

    // Create personal group
    final groupDao = GroupDao();
    final memberDao = MemberDao();

    // Generate a secret key for the personal group
    final secretKeyBytes = sha256.convert(utf8.encode('personal_${user.id}_$now')).bytes;
    final secretKey = Uint8List.fromList(secretKeyBytes);

    final personalGroup = Group(
      id: 'personal_${user.id}',
      name: 'Personal Expenses',
      secretKey: secretKey,
      createdBy: user.id,
      currencies: currencies,
      defaultCurrency: defaultCurrency,
      isPersonal: true,
      shareState: ShareState.local,
      isSharedAcrossDevices: false,
      syncMethod: SyncMethod.manual,
      createdAt: now,
      updatedAt: now,
    );
    await groupDao.insertGroup(personalGroup);

    // Create member for user in personal group
    final personalMember = Member(
      id: 'member_personal_${user.id}',
      groupId: personalGroup.id,
      name: username,
      colorHex: AppConstants.personalGroupColor,
      role: MemberRole.admin,
      joinMethod: JoinMethod.manual,
      addedAt: now,
      addedBy: user.id,
    );
    await memberDao.insertMember(personalMember);

    setState(() {
      _appState = AppState.unlocked;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, $username!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleUnlock(String pin) async {
    final securityManager = SecurityManager();
    final passphrase = await securityManager.unlockWithPin(pin);

    if (passphrase == null) {
      _handleUnlockFailed();
      return;
    }

    // Open database
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.openDatabase(passphrase);

    setState(() {
      _appState = AppState.unlocked;
      _failedAttempts = 0;
    });
  }

  void _handleUnlockFailed() {
    setState(() {
      _failedAttempts++;
      if (_failedAttempts >= AppConstants.maxLoginAttempts) {
        // Show error and reset attempts after delay
        Future.delayed(AppConstants.lockoutDuration, () {
          if (mounted) {
            setState(() {
              _failedAttempts = 0;
            });
          }
        });
      }
    });

    if (mounted && _failedAttempts >= AppConstants.maxLoginAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too many failed attempts. Please wait 30 seconds.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}

enum AppState {
  loading,
  setup,
  locked,
  unlocked,
}

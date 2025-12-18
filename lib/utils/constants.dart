/// Application-wide constants
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // Security constants
  static const int maxLoginAttempts = 3;
  static const Duration lockoutDuration = Duration(seconds: 30);

  // Balance calculation constants
  static const double balanceThreshold = 0.01; // Minimum balance to consider non-zero

  // Personal group constants
  static const String personalGroupColor = '#4CAF50'; // Green color for personal group

  // Database constants
  static const int databaseVersion = 10;
  static const String databaseName = 'delt.db';

  // Export/Import constants
  static const int exportVersion = 1;
  static const String exportType = 'delt_group_export';

  // Default values
  static const String defaultCurrency = 'EUR';
}

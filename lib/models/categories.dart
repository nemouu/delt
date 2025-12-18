/// Default expense categories
class Categories {
  // Category constants
  static const String food = 'Food & Dining';
  static const String groceries = 'Groceries';
  static const String transportation = 'Transportation';
  static const String entertainment = 'Entertainment';
  static const String shopping = 'Shopping';
  static const String bills = 'Bills & Utilities';
  static const String healthcare = 'Healthcare';
  static const String travel = 'Travel';
  static const String housing = 'Housing';
  static const String other = 'Other';

  static const List<String> defaultCategories = [
    food,
    groceries,
    transportation,
    entertainment,
    shopping,
    bills,
    healthcare,
    travel,
    housing,
    other,
  ];

  // Alias for consistency
  static List<String> get allCategories => defaultCategories;

  /// Get emoji icon for category
  static String getIcon(String category) {
    switch (category) {
      case food:
        return '🍽️';
      case groceries:
        return '🛒';
      case transportation:
        return '🚗';
      case entertainment:
        return '🎬';
      case shopping:
        return '🛍️';
      case bills:
        return '📄';
      case healthcare:
        return '⚕️';
      case travel:
        return '✈️';
      case housing:
        return '🏠';
      case other:
      default:
        return '💰';
    }
  }
}

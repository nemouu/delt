/// Data model for information extracted from a receipt via OCR
class ReceiptData {
  final double? amount;
  final String? currency;
  final String? date;
  final String? category;
  final String? storeName;
  final String rawText;

  const ReceiptData({
    this.amount,
    this.currency,
    this.date,
    this.category,
    this.storeName,
    required this.rawText,
  });

  /// Returns true if at least one useful field was extracted
  bool get hasAnyData =>
      amount != null ||
      currency != null ||
      date != null ||
      category != null ||
      storeName != null;

  /// Returns true if no data was extracted
  bool get isEmpty => !hasAnyData;

  /// Create a copy with updated fields
  ReceiptData copyWith({
    double? amount,
    String? currency,
    String? date,
    String? category,
    String? storeName,
    String? rawText,
  }) {
    return ReceiptData(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      category: category ?? this.category,
      storeName: storeName ?? this.storeName,
      rawText: rawText ?? this.rawText,
    );
  }

  @override
  String toString() {
    return 'ReceiptData(amount: $amount $currency, date: $date, category: $category, store: $storeName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ReceiptData &&
        other.amount == amount &&
        other.currency == currency &&
        other.date == date &&
        other.category == category &&
        other.storeName == storeName &&
        other.rawText == rawText;
  }

  @override
  int get hashCode {
    return amount.hashCode ^
        currency.hashCode ^
        date.hashCode ^
        category.hashCode ^
        storeName.hashCode ^
        rawText.hashCode;
  }
}

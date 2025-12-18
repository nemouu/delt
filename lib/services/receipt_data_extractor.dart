import '../models/receipt_data.dart';

/// Service for extracting structured data from receipt OCR text
/// Ports logic from Kotlin ReceiptCaptureView.kt
class ReceiptDataExtractor {
  /// Main entry point: extract all data from OCR text
  static ReceiptData extractFromText(String text) {
    final lines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final currency = _extractCurrency(text);
    final amount = _extractAmount(text, lines);
    final date = _extractDate(lines);
    final categoryAndStore = _extractCategoryAndStore(text);

    return ReceiptData(
      amount: amount,
      currency: currency,
      date: date,
      category: categoryAndStore['category'],
      storeName: categoryAndStore['storeName'],
      rawText: text,
    );
  }

  // ========== CURRENCY DETECTION ==========

  static const Map<String, List<String>> _specificCurrencyCodes = {
    'NOK': ['NOK', 'NORWEGIAN KRONE', 'NORSKE KRONER'],
    'DKK': ['DKK', 'DANISH KRONE', 'DANSKE KRONER'],
    'SEK': ['SEK', 'SWEDISH KRONA', 'SVENSKA KRONOR'],
    'EUR': ['EUR', 'EURO'],
    'USD': ['USD', 'US DOLLAR'],
    'GBP': ['GBP', 'POUND'],
    'CHF': ['CHF', 'FRANC'],
    'CAD': ['CAD'],
    'AUD': ['AUD'],
    'JPY': ['JPY', 'YEN'],
  };

  static const Map<String, List<String>> _currencySymbols = {
    'EUR': ['€'],
    'USD': ['\$'],
    'GBP': ['£'],
    'JPY': ['¥'],
    'CAD': ['C\$'],
    'AUD': ['A\$'],
  };

  /// Extract currency from text using two-pass detection
  /// First pass: Look for specific currency codes (more reliable)
  /// Second pass: Look for symbols
  static String? _extractCurrency(String text) {
    final textUpper = text.toUpperCase();

    // First pass: Currency codes
    for (final entry in _specificCurrencyCodes.entries) {
      final currency = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        if (textUpper.contains(pattern)) {
          return currency;
        }
      }
    }

    // Second pass: Currency symbols (case sensitive)
    for (final entry in _currencySymbols.entries) {
      final currency = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        if (text.contains(pattern)) {
          return currency;
        }
      }
    }

    return null;
  }

  // ========== AMOUNT DETECTION ==========

  /// Extract amount from receipt text
  /// Try patterns in order of specificity, take maximum amount found
  static double? _extractAmount(String text, List<String> lines) {
    // Regex patterns in order of priority
    final amountRegexes = [
      // "TOTAL: $45.67" or "SUM: 45,67"
      RegExp(
        r'(?:TOTAL|SUM|AMOUNT|PAID|DUE)[:\s]*[\$€£¥]?\s*(\d+[.,]\d{2})',
        caseSensitive: false,
      ),
      // "$45.67"
      RegExp(r'[\$€£¥]\s*(\d+[.,]\d{2})'),
      // "45.67$"
      RegExp(r'(\d+[.,]\d{2})\s*[\$€£¥]'),
      // Standalone decimal number "45.67"
      RegExp(r'(?:^|\s)(\d+[.,]\d{2})(?:\s|$)'),
    ];

    double maxAmount = 0.0;

    for (final line in lines) {
      for (final regex in amountRegexes) {
        final matches = regex.allMatches(line);

        for (final match in matches) {
          final amountStr = match.group(1);
          if (amountStr != null) {
            // Replace comma with dot for parsing
            final normalized = amountStr.replaceAll(',', '.');
            try {
              final parsedAmount = double.parse(normalized);
              if (parsedAmount > maxAmount) {
                maxAmount = parsedAmount;
              }
            } catch (e) {
              // Skip invalid numbers
            }
          }
        }
      }
    }

    return maxAmount > 0.0 ? maxAmount : null;
  }

  // ========== DATE DETECTION ==========

  /// Extract date from receipt text
  /// Supports multiple formats: MM/DD/YYYY, YYYY-MM-DD, DD.MM.YYYY, month names
  static String? _extractDate(List<String> lines) {
    final dateRegexes = [
      // MM/DD/YYYY or DD/MM/YYYY
      RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'),
      // YYYY-MM-DD
      RegExp(r'\d{4}[/-]\d{1,2}[/-]\d{1,2}'),
      // DD.MM.YYYY
      RegExp(r'\d{1,2}\.\d{1,2}\.\d{2,4}'),
      // "Jan 15, 2025" or "January 15 2025"
      RegExp(
        r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4}',
        caseSensitive: false,
      ),
    ];

    for (final line in lines) {
      for (final regex in dateRegexes) {
        final match = regex.firstMatch(line);
        if (match != null) {
          return match.group(0);
        }
      }
    }

    return null;
  }

  // ========== CATEGORY & STORE NAME DETECTION ==========

  /// Generic terms that shouldn't be used as store names
  static const Set<String> _genericTerms = {
    'grocery',
    'supermarket',
    'market',
    'produce',
    'food',
    'vegetables',
    'fruits',
    'restaurant',
    'cafe',
    'coffee',
    'dine',
    'menu',
    'table',
    'server',
    'tip',
    'gratuity',
    'gas',
    'fuel',
    'petrol',
    'station',
    'parking',
    'toll',
    'transit',
    'metro',
    'train',
    'bus',
    'store',
    'retail',
    'shop',
    'mall',
    'boutique',
    'clothing',
    'fashion',
    'movie',
    'cinema',
    'theater',
    'ticket',
    'entertainment',
    'game',
    'amusement',
    'pharmacy',
    'drug',
    'medical',
    'health',
    'doctor',
    'clinic',
    'hospital',
    'medicine',
    'prescription',
    'electric',
    'water',
    'utility',
    'internet',
    'phone',
    'mobile',
    'pizza',
    'burger',
    'kebab',
    'grill',
  };

  /// Category keywords mapped to category names
  static const Map<String, List<String>> _categoryKeywords = {
    'Groceries': [
      'grocery',
      'supermarket',
      'market',
      'produce',
      'food',
      'vegetables',
      'fruits',
      'walmart',
      'target',
      'costco',
      'trader joe',
      'whole foods',
      'safeway',
      'kroger',
      'spar',
      'eurospar',
      'rema',
      'kiwi',
      'coop',
      'meny',
      'joker',
      'bunnpris',
      'lidl',
      'aldi',
      'rewe',
      'edeka',
      'penny',
      'netto',
      'kaufland',
      'carrefour',
      'tesco',
      'sainsbury',
      'asda',
      'morrison',
      'ica',
      'hemköp',
    ],
    'Food & Dining': [
      'restaurant',
      'cafe',
      'coffee',
      'dine',
      'menu',
      'table',
      'server',
      'tip',
      'gratuity',
      'starbucks',
      'mcdonald',
      'subway',
      'pizza',
      'burger',
      'kebab',
      'grill',
    ],
    'Transportation': [
      'gas',
      'fuel',
      'petrol',
      'station',
      'uber',
      'lyft',
      'taxi',
      'parking',
      'toll',
      'transit',
      'metro',
      'train',
      'bus',
      'shell',
      'esso',
      'circle k',
      'statoil',
      'yx',
    ],
    'Shopping': [
      'store',
      'retail',
      'shop',
      'mall',
      'boutique',
      'clothing',
      'fashion',
      'amazon',
      'ebay',
      'nike',
      'adidas',
      'h&m',
      'zara',
      'primark',
    ],
    'Entertainment': [
      'movie',
      'cinema',
      'theater',
      'ticket',
      'entertainment',
      'game',
      'amusement',
      'netflix',
      'spotify',
      'steam',
      'kino',
    ],
    'Healthcare': [
      'pharmacy',
      'drug',
      'medical',
      'health',
      'doctor',
      'clinic',
      'hospital',
      'medicine',
      'cvs',
      'walgreens',
      'prescription',
      'apotek',
      'apoteket',
    ],
    'Bills & Utilities': [
      'electric',
      'water',
      'gas',
      'utility',
      'internet',
      'phone',
      'mobile',
      'verizon',
      'at&t',
      'comcast',
      'telenor',
      'telia',
      'tele2',
    ],
  };

  /// Extract category and store name using keyword matching
  /// Returns a map with 'category' and 'storeName' keys
  static Map<String, String?> _extractCategoryAndStore(String text) {
    final textLower = text.toLowerCase();
    int maxMatches = 0;
    String? detectedCategory;
    String? matchedStoreName;

    for (final entry in _categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      int matches = 0;
      String? bestStoreMatch;
      int bestStoreMatchLength = 0;

      for (final keyword in keywords) {
        if (textLower.contains(keyword)) {
          matches++;
          // Track the longest matching store name (not generic term)
          if (!_genericTerms.contains(keyword) &&
              keyword.length > bestStoreMatchLength) {
            bestStoreMatch = keyword;
            bestStoreMatchLength = keyword.length;
          }
        }
      }

      if (matches > maxMatches) {
        maxMatches = matches;
        detectedCategory = category;
        matchedStoreName = bestStoreMatch;
      }
    }

    // Capitalize store name properly for display
    String? formattedStoreName;
    if (matchedStoreName != null) {
      formattedStoreName = matchedStoreName
          .split(' ')
          .map((word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }

    return {
      'category': detectedCategory,
      'storeName': formattedStoreName,
    };
  }
}

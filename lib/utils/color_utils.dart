import 'package:flutter/material.dart';

/// Utility class for color operations
class ColorUtils {
  ColorUtils._(); // Private constructor to prevent instantiation

  /// Parse a hex color string (e.g., "#4CAF50") to a Color object
  /// Returns the fallback color if parsing fails
  static Color parseHexColor(String hexColor, {Color fallback = Colors.grey}) {
    try {
      // Remove the '#' if present and parse the hex string
      final hex = hexColor.startsWith('#') ? hexColor.substring(1) : hexColor;
      return Color(int.parse(hex, radix: 16) + 0xFF000000);
    } catch (e) {
      return fallback;
    }
  }

  /// Convert a Color object to hex string format (e.g., "#4CAF50")
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Create a color with adjusted opacity
  /// Replaces the deprecated withOpacity() method
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }
}

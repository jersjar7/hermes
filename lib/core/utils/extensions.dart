// lib/core/utils/extensions.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Extensions for [String] class
extension StringExtensions on String {
  /// Capitalize the first letter of the string
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Convert string to title case (capitalize first letter of each word)
  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Try to parse the string as JSON
  dynamic tryParseJson() {
    try {
      return json.decode(this);
    } catch (e) {
      return null;
    }
  }

  /// Check if the string is a valid email
  bool get isValidEmail {
    final emailRegExp = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    return emailRegExp.hasMatch(this);
  }

  /// Check if the string is numeric
  bool get isNumeric {
    if (isEmpty) return false;
    return double.tryParse(this) != null;
  }

  /// Calculate the Levenshtein distance between this string and another
  int levenshteinDistanceTo(String other) {
    if (this == other) return 0;
    if (isEmpty) return other.length;
    if (other.isEmpty) return length;

    List<int> v0 = List<int>.filled(other.length + 1, 0);
    List<int> v1 = List<int>.filled(other.length + 1, 0);

    for (int i = 0; i <= other.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < other.length; j++) {
        int cost = (this[i] == other[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }

      for (int j = 0; j <= other.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[other.length];
  }
}

/// Extensions for [DateTime] class
extension DateTimeExtensions on DateTime {
  /// Format the date as 'yyyy-MM-dd'
  String get formattedDate => DateFormat('yyyy-MM-dd').format(this);

  /// Format the date as 'yyyy-MM-dd HH:mm:ss'
  String get formattedDateTime =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(this);

  /// Format the time as 'HH:mm'
  String get formattedTime => DateFormat('HH:mm').format(this);

  /// Check if the date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if the date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Check if the date is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// Get a human-readable time ago string (e.g. "2 hours ago")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'just now';
    }
  }
}

/// Extensions for [BuildContext] class
extension BuildContextExtensions on BuildContext {
  /// Get the current [MediaQueryData]
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Get the screen size
  Size get screenSize => mediaQuery.size;

  /// Get the screen width
  double get screenWidth => screenSize.width;

  /// Get the screen height
  double get screenHeight => screenSize.height;

  /// Get the current [ThemeData]
  ThemeData get theme => Theme.of(this);

  /// Get the current text theme
  TextTheme get textTheme => theme.textTheme;

  /// Get the primary color
  Color get primaryColor => theme.primaryColor;

  /// Get the color scheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Check if the screen is in dark mode
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Show a snackbar
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(
      this,
    ).showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  /// Pop the current route
  void pop<T>([T? result]) => Navigator.of(this).pop(result);

  /// Push a named route
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) =>
      Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
}

/// Extensions for [List] class
extension ListExtensions<T> on List<T> {
  /// Get a random element from the list
  T? get randomElement {
    if (isEmpty) return null;
    return this[DateTime.now().millisecondsSinceEpoch % length];
  }

  /// Check if the list contains all elements from another list
  bool containsAll(List<T> elements) {
    for (final element in elements) {
      if (!contains(element)) return false;
    }
    return true;
  }

  /// Split the list into chunks of the specified size
  List<List<T>> chunked(int chunkSize) {
    final result = <List<T>>[];
    for (var i = 0; i < length; i += chunkSize) {
      result.add(sublist(i, i + chunkSize > length ? length : i + chunkSize));
    }
    return result;
  }
}

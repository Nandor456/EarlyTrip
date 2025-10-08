import 'package:intl/intl.dart';

/// A utility class for consistently formatting date and time objects
/// throughout the application.
class DateFormatter {
  /// Formats a DateTime object into a human-readable format.
  ///
  /// Example format: "Oct 7, 2025 at 1:21 PM"
  static String formatDateTime(DateTime dateTime) {
    // Determine if the date is today or a previous day
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date.isAtSameMomentAs(today)) {
      // If today, show only the time
      return DateFormat.jm().format(dateTime); // e.g., 1:21 PM
    } else if (today.difference(date).inDays == 1) {
      // If yesterday, show 'Yesterday' and time
      return 'Yesterday, ${DateFormat.jm().format(dateTime)}';
    } else {
      // Otherwise, show full date and time
      return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
    }
  }

  /// Formats a DateTime object into a standard date string.
  /// This is suitable for displaying creation dates.
  ///
  /// Example format: "October 7, 2025"
  static String formatDate(DateTime dateTime) {
    return DateFormat.yMMMMd().format(dateTime);
  }

  /// Formats a DateTime object into a short date string for message grouping.
  ///
  /// Example format: "10/7/25"
  static String formatShortDate(DateTime dateTime) {
    return DateFormat.yMd().format(dateTime);
  }
}

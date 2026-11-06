import 'dart:io';

class ErrorHelper {
  static String getFriendlyMessage(dynamic error, [int? statusCode]) {
    if (statusCode != null) {
      if (statusCode == 401) return 'Session expired, please sign in again';
      if (statusCode == 403) return "You don't have permission";
      if (statusCode == 404) return 'Not found';
      if (statusCode >= 500) return 'Server problem, try again later';
      return 'An unexpected error occurred';
    }

    final str = error.toString().toLowerCase();
    if (error is SocketException ||
        str.contains('socket') ||
        str.contains('timeout') ||
        str.contains('connection')) {
      return 'Check your connection';
    }

    return 'An error occurred. Please try again.';
  }
}

import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class ErrorHandler {
  /// Convert technical errors to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (error is http.ClientException) {
      return 'Unable to connect to server. Please check your internet connection.';
    }

    if (error is TimeoutException) {
      return 'Connection timeout. Please try again.';
    }

    if (error is HttpException) {
      return 'Network error occurred. Please try again.';
    }

    if (error is FormatException) {
      return 'Unable to process data. Please try again later.';
    }

    // Check if error message contains URL or technical details
    final errorString = error.toString();

    if (errorString.contains('http://') || errorString.contains('https://')) {
      return 'Unable to load data. Please check your internet connection.';
    }

    if (errorString.contains('Failed to load')) {
      return 'Unable to load data. Please try again.';
    }

    if (errorString.contains('SocketException') ||
        errorString.contains('Connection')) {
      return 'No internet connection. Please check your network.';
    }

    // For any other unknown errors, return generic message
    return 'Something went wrong. Please try again.';
  }
}

import 'dart:convert';
import 'dart:developer' as developer;

/// Lightweight shared logger for API request/response/error debugging.
///
/// This file is intentionally small to avoid pulling in a larger logging
/// package. It uses `dart:developer.log` so the output is visible in
/// debugger consoles and tooling that collects Dart logs.
class AppLogger {
  static const _source = 'app_logger';

  static void apiRequest(String operation, {Object? details}) {
    developer.log(
      'API REQUEST $operation ${_formatDetails(details)}',
      name: _source,
      level: 800,
    );
  }

  static void apiResponse(String operation,
      {Object? details, int? statusCode}) {
    final statusPart = statusCode != null ? ' statusCode=$statusCode' : '';
    developer.log(
      'API RESPONSE $operation$statusPart ${_formatDetails(details)}',
      name: _source,
      level: 800,
    );
  }

  static void apiError(
    String operation,
    Object error, {
    StackTrace? stackTrace,
    Object? details,
    String? message,
  }) {
    developer.log(
      'API ERROR $operation${message != null ? ' - $message' : ''} ${_formatDetails(details)}',
      name: _source,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _formatDetails(Object? details) {
    if (details == null) return '';
    if (details is String) return details;
    try {
      return jsonEncode(details);
    } catch (_) {
      return details.toString();
    }
  }
}

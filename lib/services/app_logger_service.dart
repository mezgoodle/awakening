import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum LogSeverity {
  debug,
  info,
  warning,
  error,
}

class AppLoggerService {
  static final AppLoggerService _instance = AppLoggerService._internal();
  factory AppLoggerService() => _instance;
  AppLoggerService._internal();

  FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeLog({
    required String message,
    LogSeverity severity = LogSeverity.info,
    Map<String, dynamic>? payload,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    if (kDebugMode) {
      final payloadStr = payload != null ? ' | Payload: $payload' : '';
      final errStr = error != null ? ' | Error: $error' : '';
      debugPrint('[${severity.name.toUpperCase()}] $message$payloadStr$errStr');
    }

    try {
      if (!kIsWeb && (severity == LogSeverity.error || severity == LogSeverity.warning)) {
        await FirebaseCrashlytics.instance.recordError(
          error ?? Exception(message),
          stackTrace ?? StackTrace.current,
          reason: message,
          information: payload != null ? [payload.toString()] : const [],
          fatal: false,
        );
      }

      if (severity == LogSeverity.info && payload != null) {
        final sanitizedEventName = message
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
            .replaceAll(RegExp(r'_+'), '_');
        final trimmedName = sanitizedEventName.length > 40
            ? sanitizedEventName.substring(0, 40)
            : sanitizedEventName;
        if (trimmedName.isNotEmpty) {
          final Map<String, Object> sanitizedParams = {};
          payload.forEach((key, val) {
            final paramKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
            if (val is num || val is String) {
              sanitizedParams[paramKey] = val;
            } else {
              sanitizedParams[paramKey] = val.toString();
            }
          });
          await _analytics?.logEvent(
            name: trimmedName,
            parameters: sanitizedParams.isNotEmpty ? sanitizedParams : null,
          );
        }
      }
    } catch (_) {
      // Avoid crash on logging failure
    }
  }
}

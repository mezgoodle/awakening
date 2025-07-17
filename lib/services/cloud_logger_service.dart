import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/logging/v2.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

enum MessageSeverity {
  info,
  warning,
  error,
  debug,
}

class CloudLoggerService {
  late LoggingApi _loggingApi;
  bool _isInitialized = false;
  late final String _projectId;

  static final CloudLoggerService _instance = CloudLoggerService._internal();
  factory CloudLoggerService() => _instance;

  CloudLoggerService._internal() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/service_account.json');
      final credentialsJson = jsonDecode(jsonString);

      _projectId = credentialsJson['project_id'];

      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);

      final scopes = [LoggingApi.loggingWriteScope];
      final client = await clientViaServiceAccount(credentials, scopes);

      _loggingApi = LoggingApi(client);
      _isInitialized = true;
      print(
          "CloudLoggerService Initialized Successfully (via Service Account). Project ID: $_projectId");
    } catch (e) {
      print("!!! FATAL ERROR INITIALIZING CloudLoggerService: $e");
      print(
          "!!! Logging to GCP will not work. Check 'assets/service_account.json'.");
      _isInitialized = false;
    }
  }

  String _severityToString(MessageSeverity severity) {
    switch (severity) {
      case MessageSeverity.info:
        return 'INFO';
      case MessageSeverity.warning:
        return 'WARNING';
      case MessageSeverity.error:
        return 'ERROR';
      case MessageSeverity.debug:
        return 'DEBUG';
      default:
        return 'UNKNOWN';
    }
  }

  Future<void> writeLog({
    required String message,
    MessageSeverity severity = MessageSeverity.info,
    String logName = 'flutter-app-log',
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized) {
      if (!_isInitialized) await _initialize();
      if (!_isInitialized) {
        print("CloudLoggerService not initialized. Skipping log.");
        return;
      }
    }

    final fullLogName = 'projects/$_projectId/logs/$logName';
    final platform = defaultTargetPlatform.toString().split('.').last;

    final entry = LogEntry(
      logName: fullLogName,
      severity: _severityToString(severity),
      resource: MonitoredResource(type: 'global'),
      jsonPayload: payload,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      labels: {"platform": platform},
      textPayload: payload == null ? message : null,
    );

    final request = WriteLogEntriesRequest(entries: [entry]);

    try {
      await _loggingApi.entries.write(request);
      print("Log sent to GCP: $message");
    } catch (e) {
      print("Error sending log to GCP: $e");
    }
  }
}

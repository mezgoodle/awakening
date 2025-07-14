// lib/services/cloud_logger_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudLoggerService {
  final String? _apiKey;
  final String? _projectId;
  bool _isInitialized = false;

  static final CloudLoggerService _instance = CloudLoggerService._internal();
  factory CloudLoggerService() => _instance;

  CloudLoggerService._internal()
      : _apiKey = dotenv.env['GCP_LOGGING_API_KEY'],
        _projectId = "gen-lang-client-0957500330" {
    _initialize();
  }

  void _initialize() {
    if (_apiKey == null || _apiKey!.isEmpty) {
      print(
          "!!! CloudLoggerService: GCP_LOGGING_API_KEY not found in .env file.");
      _isInitialized = false;
      return;
    }
    if (_projectId == null || _projectId!.isEmpty) {
      print("!!! CloudLoggerService: GCP_PROJECT_ID not found in .env file.");
      _isInitialized = false;
      return;
    }
    _isInitialized = true;
    print("CloudLoggerService Initialized. Project ID: $_projectId");
  }

  Future<void> writeLog({
    required String message,
    String severity = 'INFO', // INFO, WARNING, ERROR, DEBUG
    String logName = 'flutter-app-log', // Назва лог-стріму
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized) {
      print("CloudLoggerService not initialized. Skipping log.");
      return;
    }

    // Формуємо URL для Cloud Logging API
    final url = Uri.parse(
        'https://logging.googleapis.com/v2/entries:write?key=$_apiKey');

    final fullLogName = 'projects/$_projectId/logs/$logName';

    final logEntry = {
      "logName": fullLogName,
      "resource": {"type": "global"}, // Найпростіший тип ресурсу
      "severity": severity,
      "jsonPayload": {
        "message": message,
        if (payload != null) ...payload,
      },
    };

    final body = {
      "entries": [logEntry]
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("Log sent to GCP successfully: $message");
      } else {
        print("Error sending log to GCP. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Exception while sending log to GCP: $e");
    }
  }
}

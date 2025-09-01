import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, debugPrint, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/logging/v2.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

enum CloudLogSeverity {
  info,
  warning,
  error,
  debug,
}

class CloudLoggerService {
  late LoggingApi _loggingApi;
  bool _isInitialized = false;
  late final String _projectId;
  final String _sessionId = const Uuid().v4();
  Map<String, dynamic>? _deviceInfo;
  PackageInfo? _packageInfo;

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
      debugPrint(
          "CloudLoggerService Initialized Successfully (via Service Account). Project ID: $_projectId");

      await _getDeviceAndPackageInfo();
    } catch (e) {
      debugPrint("!!! FATAL ERROR INITIALIZING CloudLoggerService: $e");
      debugPrint(
          "!!! Logging to GCP will not work. Check 'assets/service_account.json'.");
      _isInitialized = false;
    }
  }

  Future<void> _getDeviceAndPackageInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      _packageInfo = await PackageInfo.fromPlatform();

      if (kIsWeb) {
        _deviceInfo = (await deviceInfoPlugin.webBrowserInfo).data;
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            _deviceInfo = (await deviceInfoPlugin.androidInfo).data;
            break;
          case TargetPlatform.iOS:
            _deviceInfo = (await deviceInfoPlugin.iosInfo).data;
            break;
          case TargetPlatform.linux:
            _deviceInfo = (await deviceInfoPlugin.linuxInfo).data;
            break;
          case TargetPlatform.macOS:
            _deviceInfo = (await deviceInfoPlugin.macOsInfo).data;
            break;
          case TargetPlatform.windows:
            _deviceInfo = (await deviceInfoPlugin.windowsInfo).data;
            break;
          default:
            _deviceInfo = null;
        }
      }
    } catch (e) {
      debugPrint("Error getting device/package info: $e");
    }
  }

  String _severityToString(CloudLogSeverity severity) {
    switch (severity) {
      case CloudLogSeverity.info:
        return 'INFO';
      case CloudLogSeverity.warning:
        return 'WARNING';
      case CloudLogSeverity.error:
        return 'ERROR';
      case CloudLogSeverity.debug:
        return 'DEBUG';
    }
  }

  Future<void> writeLog({
    required String message,
    CloudLogSeverity severity = CloudLogSeverity.info,
    String logName = 'flutter-app-log',
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized) {
      if (!_isInitialized) await _initialize();
      if (!_isInitialized) {
        debugPrint("CloudLoggerService not initialized. Skipping log.");
        return;
      }
    }

    final fullLogName = 'projects/$_projectId/logs/$logName';
    final platform =
        kIsWeb ? 'web' : defaultTargetPlatform.toString().split('.').last;

    final Map<String, dynamic> globalContext = {
      'message': message,
      'app': {
        'version': _packageInfo?.version,
        'buildNumber': _packageInfo?.buildNumber,
        'appName': _packageInfo?.appName,
        'packageName': _packageInfo?.packageName,
      },
      'device': _deviceInfo,
      'platform': platform,
      'sessionId': _sessionId,
    };

    final finalPayload = Map<String, dynamic>.from(globalContext);
    if (payload != null) {
      finalPayload['context'] = payload;
    }

    final entry = LogEntry(
      logName: fullLogName,
      severity: _severityToString(severity),
      resource: MonitoredResource(type: 'global'),
      jsonPayload: finalPayload,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      labels: {"platform": platform},
    );

    final request = WriteLogEntriesRequest(entries: [entry]);

    try {
      await _loggingApi.entries.write(request);
      debugPrint("Log sent to GCP: $message");
    } catch (e) {
      debugPrint("Error sending log to GCP: $e");
    }
  }
}

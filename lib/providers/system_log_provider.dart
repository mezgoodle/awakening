import 'dart:collection';
import 'dart:convert';
import 'package:awakening/providers/player_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/system_message_model.dart';
import '../services/cloud_logger_service.dart';

class SystemLogProvider with ChangeNotifier {
  List<SystemMessageModel> _messages = [];
  SystemMessageModel? _latestMessageForSnackbar;

  static const String _logKey = 'systemLogData';
  static const int _maxLogSize = 100;

  PlayerProvider? _playerProvider;
  CloudLoggerService? _cloudLogger;

  UnmodifiableListView<SystemMessageModel> get messages =>
      UnmodifiableListView(_messages);
  SystemMessageModel? get latestMessageForSnackbar {
    final msg = _latestMessageForSnackbar;
    _latestMessageForSnackbar = null;
    return msg;
  }

  SystemLogProvider();

  void update(PlayerProvider? playerProvider, CloudLoggerService? logger) {
    print(
        "SystemLogProvider UPDATE called. Logger is ${logger == null ? 'null' : 'NOT null'}");
    _playerProvider = playerProvider;
    _cloudLogger = logger;
  }

  void addMessage(String text, MessageType type,
      {bool showInSnackbar = true, Map<String, dynamic>? payload}) {
    final newMessage = SystemMessageModel(text: text, type: type);

    // Оновлюємо UI
    _messages.insert(0, newMessage);
    if (showInSnackbar) {
      _latestMessageForSnackbar = newMessage;
    }
    notifyListeners();

    // Відправляємо лог в GCP через наш сервіс
    if (_cloudLogger != null) {
      String severity;
      switch (type) {
        case MessageType.error:
          severity = 'ERROR';
          break;
        case MessageType.warning:
          severity = 'WARNING';
          break;
        default:
          severity = 'INFO';
      }

      Map<String, dynamic> finalPayload = {
        'message': text,
        'userId': _playerProvider?.getUserId() ?? 'unknown',
        'logType': type.name,
      };
      if (payload != null) {
        finalPayload.addAll(payload);
      }

      _cloudLogger!.writeLog(
        message: text,
        severity: severity,
        payload: finalPayload,
      );
    }
  }

  Future<void> clearLog() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
    notifyListeners();
  }
}

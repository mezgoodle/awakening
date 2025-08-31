import 'dart:collection';
import 'package:awakening/providers/player_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awakening/models/system_message_model.dart';
import 'package:awakening/services/cloud_logger_service.dart';

class SystemLogProvider with ChangeNotifier {
  List<SystemMessageModel> _messages = [];
  SystemMessageModel? _latestMessageForSnackbar;

  static const String _logKey = 'systemLogData';

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
    debugPrint(
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
  }

  Future<void> clearLog() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
    notifyListeners();
  }
}

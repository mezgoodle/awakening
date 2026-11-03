import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/system_message_model.dart';
import '../services/app_logger_service.dart';

class SystemLogProvider with ChangeNotifier {
  static const String _storageKey = 'system_messages_log';
  final List<SystemMessageModel> _messages = [];
  final StreamController<SystemMessageModel> _snackbarStreamController =
      StreamController<SystemMessageModel>.broadcast();

  SystemMessageModel? _pendingSnackbarMessage;
  final AppLoggerService _logger = AppLoggerService();

  UnmodifiableListView<SystemMessageModel> get messages =>
      UnmodifiableListView(_messages);
  Stream<SystemMessageModel> get snackbarStream =>
      _snackbarStreamController.stream;

  SystemMessageModel? consumeLatestSnackbarMessage() {
    final msg = _pendingSnackbarMessage;
    _pendingSnackbarMessage = null;
    return msg;
  }

  SystemLogProvider() {
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey);
      if (jsonList != null) {
        _messages.clear();
        for (final item in jsonList) {
          try {
            _messages.add(
                SystemMessageModel.fromJson(jsonDecode(item) as Map<String, dynamic>));
          } catch (_) {}
        }
        notifyListeners();
      }
    } catch (e) {
      _logger.writeLog(
        message: "Failed to load cached system messages: $e",
        severity: LogSeverity.warning,
      );
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limitedList = _messages.take(100).toList();
      final stringList = limitedList.map((m) => jsonEncode(m.toJson())).toList();
      await prefs.setStringList(_storageKey, stringList);
    } catch (_) {}
  }

  void addMessage(String text, MessageType type,
      {bool showInSnackbar = true, Map<String, dynamic>? payload}) {
    final newMessage = SystemMessageModel(text: text, type: type);
    _messages.insert(0, newMessage);

    if (showInSnackbar) {
      _pendingSnackbarMessage = newMessage;
      _snackbarStreamController.add(newMessage);
    }

    _saveMessages();
    notifyListeners();
  }

  Future<void> clearLog() async {
    _messages.clear();
    _pendingSnackbarMessage = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _snackbarStreamController.close();
    super.dispose();
  }
}

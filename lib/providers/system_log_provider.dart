import 'dart:collection'; // Для UnmodifiableListView
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/system_message_model.dart';

class SystemLogProvider with ChangeNotifier {
  List<SystemMessageModel> _messages = [];
  SystemMessageModel? _latestMessageForSnackbar; // Для показу в SnackBar

  static const String _logKey = 'systemLogData';
  static const int _maxLogSize =
      100; // Максимальна кількість повідомлень в лозі

  UnmodifiableListView<SystemMessageModel> get messages =>
      UnmodifiableListView(_messages);
  SystemMessageModel? get latestMessageForSnackbar {
    final msg = _latestMessageForSnackbar;
    _latestMessageForSnackbar =
        null; // Скидаємо після отримання, щоб не показувати знову
    return msg;
  }

  SystemLogProvider() {
    _loadLog();
  }

  Future<void> _loadLog() async {
    final prefs = await SharedPreferences.getInstance();
    final String? logString = prefs.getString(_logKey);
    if (logString != null) {
      try {
        final List<dynamic> logJson = jsonDecode(logString);
        _messages = logJson
            .map((jsonItem) =>
                SystemMessageModel.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
        // Сортуємо за часом, найновіші спочатку (якщо потрібно для відображення)
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (e) {
        print("Error loading system log: $e");
        _messages = [];
      }
    }
    notifyListeners(); // Повідомити, що лог завантажено
  }

  Future<void> _saveLog() async {
    final prefs = await SharedPreferences.getInstance();
    // Перед збереженням переконуємося, що лог відсортований (найновіші на початку списку)
    // і обрізаний до _maxLogSize
    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_messages.length > _maxLogSize) {
      _messages = _messages.sublist(0, _maxLogSize);
    }
    final String logString =
        jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString(_logKey, logString);
  }

  void addMessage(String text, MessageType type, {bool showInSnackbar = true}) {
    final newMessage = SystemMessageModel(text: text, type: type);
    _messages.insert(
        0, newMessage); // Додаємо на початок списку (найновіші зверху)

    if (_messages.length > _maxLogSize) {
      _messages.removeLast(); // Видаляємо найстаріше, якщо перевищено ліміт
    }

    if (showInSnackbar) {
      _latestMessageForSnackbar = newMessage;
    }

    _saveLog();
    notifyListeners(); // Повідомити про нове повідомлення
  }

  // Метод для очищення логу (для тестування або налаштувань)
  Future<void> clearLog() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
    notifyListeners();
  }
}

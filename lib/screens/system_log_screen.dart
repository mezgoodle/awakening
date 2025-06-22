// lib/screens/system_log_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/system_message_model.dart';
import '../providers/system_log_provider.dart';

class SystemLogScreen extends StatelessWidget {
  const SystemLogScreen({super.key});

  IconData _getIconForMessageType(MessageType type) {
    switch (type) {
      case MessageType.levelUp:
      case MessageType.rankUp:
        return Icons.star_outline_rounded;
      case MessageType.questCompleted:
      case MessageType.statsIncreased:
        return Icons.check_circle_outline_rounded;
      case MessageType.questAdded:
        return Icons.playlist_add_rounded;
      case MessageType.error:
        return Icons.error_outline_rounded;
      case MessageType.warning:
        return Icons.warning_amber_rounded;
      case MessageType.info:
      case MessageType.system:
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getColorForMessageType(MessageType type, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    bool isDark = brightness == Brightness.dark;

    switch (type) {
      case MessageType.levelUp:
      case MessageType.rankUp:
        return Colors.amber[isDark ? 300 : 700]!;
      case MessageType.questCompleted:
      case MessageType.statsIncreased:
        return Colors.green[isDark ? 300 : 700]!;
      case MessageType.questAdded:
        return Colors.blue[isDark ? 300 : 700]!;
      case MessageType.error:
        return Colors.red[isDark ? 300 : 700]!;
      case MessageType.warning:
        return Colors.orange[isDark ? 300 : 700]!;
      case MessageType.info:
      case MessageType.system:
      default:
        return Colors.grey[isDark ? 400 : 600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemLogProvider = context.watch<SystemLogProvider>();
    final messages = systemLogProvider
        .messages; // Список вже відсортований (найновіші спочатку)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал Системи'),
        actions: [
          if (messages
              .isNotEmpty) // Показувати кнопку, тільки якщо є що очищати
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Очистити журнал',
              onPressed: () async {
                bool? confirmClear = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) {
                    return AlertDialog(
                      title: const Text('Очистити Журнал?'),
                      content: const Text(
                          'Ви впевнені, що хочете видалити всі системні повідомлення?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Скасувати'),
                          onPressed: () => Navigator.of(ctx).pop(false),
                        ),
                        TextButton(
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Очистити'),
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ],
                    );
                  },
                );
                if (confirmClear == true) {
                  await systemLogProvider.clearLog();
                  if (context.mounted) {
                    // Перевірка mounted після асинхронного виклику
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Журнал системи очищено.')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: messages.isEmpty
          ? Center(
              child: Text(
                'Журнал системних повідомлень порожній.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final iconColor =
                    _getColorForMessageType(message.type, context);
                return Card(
                  elevation: 1, // Невелика тінь для карток
                  margin:
                      const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                        color: iconColor.withOpacity(0.5), width: 0.5),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: ListTile(
                    leading: Icon(
                      _getIconForMessageType(message.type),
                      color: iconColor,
                      size: 28,
                    ),
                    title: Text(message.text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            // fontWeight: message.isRead ? FontWeight.normal : FontWeight.bold, // Для відмітки прочитаних
                            fontSize: 15)),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy HH:mm:ss')
                          .format(message.timestamp),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 12, color: Colors.grey[500]),
                    ),
                    // Можна додати onTap для позначки як прочитане або для якихось дій
                    // onTap: () {
                    //   // systemLogProvider.markAsRead(message.id);
                    // },
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 2), // Невеликий розділювач
            ),
    );
  }
}

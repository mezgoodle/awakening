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
        return Colors.grey[isDark ? 400 : 600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemLogProvider = context.watch<SystemLogProvider>();
    final messages = systemLogProvider.messages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Log'),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear log',
              onPressed: () async {
                bool? confirmClear = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) {
                    return AlertDialog(
                      title: const Text('Clear Log?'),
                      content: const Text(
                          'Are you sure you want to delete all system messages?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(ctx).pop(false),
                        ),
                        TextButton(
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Clear'),
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ],
                    );
                  },
                );
                if (confirmClear == true) {
                  await systemLogProvider.clearLog();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('System log cleared.')),
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
                'System message log is empty.',
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
                  elevation: 1,
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
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontSize: 15)),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy HH:mm:ss')
                          .format(message.timestamp),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 2),
            ),
    );
  }
}

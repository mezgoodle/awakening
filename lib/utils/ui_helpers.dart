import 'package:flutter/material.dart';
import '../models/system_message_model.dart';

void showSystemSnackBar(BuildContext context, SystemMessageModel message) {
  Color backgroundColor;
  IconData iconData;

  switch (message.type) {
    case MessageType.levelUp:
    case MessageType.rankUp:
      backgroundColor = Colors.amber[800]!;
      iconData = Icons.star_rounded;
      break;
    case MessageType.questCompleted:
    case MessageType.statsIncreased:
      backgroundColor = Colors.green[700]!;
      iconData = Icons.check_circle_rounded;
      break;
    case MessageType.questAdded:
      backgroundColor = Colors.blue[700]!;
      iconData = Icons.playlist_add_check_rounded;
      break;
    case MessageType.error:
      backgroundColor = Colors.red[700]!;
      iconData = Icons.error_rounded;
      break;
    case MessageType.warning:
      backgroundColor = Colors.orange[700]!;
      iconData = Icons.warning_rounded;
      break;
    case MessageType.info:
    case MessageType.system:
      backgroundColor = Colors.grey[800]!;
      iconData = Icons.info_rounded;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(iconData, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message.text,
                  style: const TextStyle(color: Colors.white, fontSize: 15))),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(10),
      duration: const Duration(seconds: 4),
    ),
  );
}

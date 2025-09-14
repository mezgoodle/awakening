// lib/widgets/quest_card.dart
import 'package:flutter/material.dart';
import '../models/quest_model.dart';
import '../models/player_model.dart'; // Для PlayerModel.getStatName

class QuestCard extends StatelessWidget {
  final QuestModel quest;
  final VoidCallback? onComplete; // Кнопка "Виконати" буде тільки для активних

  const QuestCard({
    super.key,
    required this.quest,
    this.onComplete,
  });

  // Колір для рамки/іконки залежно від складності
  Color _getDifficultyColor(QuestDifficulty difficulty, BuildContext context) {
    switch (difficulty) {
      case QuestDifficulty.S:
        return Colors.redAccent[700]!;
      case QuestDifficulty.A:
        return Colors.orangeAccent[700]!;
      case QuestDifficulty.B:
        return Colors.yellowAccent[700]!;
      case QuestDifficulty.C:
        return Colors.lightGreenAccent[700]!;
      case QuestDifficulty.D:
        return Colors.lightBlueAccent[400]!;
      case QuestDifficulty.E:
        return Colors.grey[500]!;
      case QuestDifficulty.F:
        return Colors.grey[700]!;
    }
  }

  IconData _getQuestTypeIcon(QuestType type) {
    switch (type) {
      case QuestType.daily:
        return Icons.wb_sunny_outlined;
      case QuestType.weekly:
        return Icons.calendar_view_week_outlined;
      case QuestType.milestone:
        return Icons.flag_outlined;
      case QuestType.generated:
        return Icons.auto_awesome_outlined; // або auro_fix_high
      case QuestType.story:
        return Icons.menu_book_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difficultyColor = _getDifficultyColor(quest.difficulty, context);

    return Card(
      // margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      // elevation вже в темі, margin теж
      shape: RoundedRectangleBorder(
        // Додамо рамку кольору складності
        side: BorderSide(color: difficultyColor, width: 1.5),
        borderRadius: BorderRadius.circular(8.0), // Такий же як в CardTheme
      ),
      child: InkWell(
        onTap: () {
          // Показати деталі квесту в діалоговому вікні
          showDialog(
            context: context,
            builder: (BuildContext ctx) {
              return AlertDialog(
                backgroundColor:
                    theme.cardTheme.color, // Використовуємо колір з теми
                title: Row(
                  children: [
                    Icon(_getQuestTypeIcon(quest.type),
                        color: theme.textTheme.titleLarge?.color, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(quest.title,
                            style: theme.textTheme.titleLarge)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text(
                          'Ранг: ${QuestModel.getQuestDifficultyName(quest.difficulty)}',
                          style: TextStyle(
                              color: difficultyColor,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(quest.description,
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Text('Нагорода:',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('XP: ${quest.xpReward}',
                          style: theme.textTheme.bodyMedium),
                      if (quest.itemRewards != null) ...[
                        const SizedBox(height: 8),
                        Text('Предмети:',
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: quest.itemRewards!.map((item) {
                            return Text('${item["name"]}',
                                style: theme.textTheme.bodyMedium);
                          }).toList(),
                        ),
                      ],
                      if (quest.targetStat != null) ...[
                        const SizedBox(height: 8),
                        Text(
                            'Фокус: ${PlayerModel.getStatName(quest.targetStat!)}',
                            style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 8),
                      Text('Тип: ${QuestModel.getQuestTypeName(quest.type)}',
                          style: theme.textTheme.bodyMedium),
                      if (quest.createdAt != null)
                        Text(
                            'Додано: ${quest.createdAt!.day.toString().padLeft(2, '0')}.${quest.createdAt!.month.toString().padLeft(2, '0')}.${quest.createdAt!.year}',
                            style: theme.textTheme.bodySmall),
                      if (quest.isCompleted && quest.completedAt != null)
                        Text(
                            'Виконано: ${quest.completedAt!.day.toString().padLeft(2, '0')}.${quest.completedAt!.month.toString().padLeft(2, '0')}.${quest.completedAt!.year}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.greenAccent)),
                    ],
                  ),
                ),
                actions: <Widget>[
                  if (onComplete != null && !quest.isCompleted)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Виконати'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700]),
                      onPressed: () {
                        Navigator.of(ctx).pop(); // Закриваємо діалог
                        onComplete!(); // Викликаємо зовнішній onComplete (який покаже свій діалог)
                      },
                    ),
                  TextButton(
                    child: const Text('Закрити'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(_getQuestTypeIcon(quest.type),
                            color: theme.textTheme.titleMedium?.color,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            quest.title,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: difficultyColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: difficultyColor, width: 1)),
                    child: Text(
                      QuestModel.getQuestDifficultyName(quest.difficulty),
                      style: TextStyle(
                          color: difficultyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quest.description,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'XP: ${quest.xpReward}',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber[300],
                        fontWeight: FontWeight.w500),
                  ),
                  if (onComplete != null && !quest.isCompleted)
                    ElevatedButton(
                      onPressed: onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text('Виконати'),
                    ),
                  if (quest.isCompleted)
                    const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 18),
                        SizedBox(width: 4),
                        Text('Виконано',
                            style: TextStyle(
                                color: Colors.greenAccent, fontSize: 14)),
                      ],
                    )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

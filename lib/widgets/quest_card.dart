import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';
import '../providers/item_provider.dart';
import '../utils/rank_extensions.dart';

class QuestCard extends StatelessWidget {
  final QuestModel quest;
  final VoidCallback? onComplete;

  const QuestCard({
    super.key,
    required this.quest,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difficultyColor = quest.difficulty.color;
    final itemProvider = context.read<ItemProvider>();

    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: difficultyColor, width: 1.5),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext ctx) {
              return AlertDialog(
                backgroundColor: theme.cardTheme.color,
                title: Row(
                  children: [
                    Icon(
                      quest.type.icon,
                      color: theme.textTheme.titleLarge?.color,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(quest.title,
                          style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text(
                        'Rank: ${quest.difficulty.rankName}',
                        style: TextStyle(
                          color: difficultyColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(quest.description,
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Text(
                        'Rewards:',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text('• XP: +${quest.xpReward}',
                          style: theme.textTheme.bodyMedium),
                      if (quest.itemRewards != null &&
                          quest.itemRewards!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...quest.itemRewards!.map((reward) {
                          final itemName = itemProvider
                                  .getItemById(reward.itemId)
                                  ?.name ??
                              reward.itemId;
                          return Text(
                            '• Item: $itemName x${reward.quantity}',
                            style: theme.textTheme.bodyMedium,
                          );
                        }),
                      ],
                      if (quest.targetStat != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Focus Stat: ${PlayerModel.getStatName(quest.targetStat!)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (quest.hpCostOnCompletion != null &&
                          quest.hpCostOnCompletion! > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Exertion: -${quest.hpCostOnCompletion} HP on completion',
                          style: TextStyle(
                            color: Colors.redAccent[100],
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text('Type: ${quest.type.displayName}',
                          style: theme.textTheme.bodySmall),
                      if (quest.createdAt != null)
                        Text(
                          'Assigned: ${quest.createdAt!.day.toString().padLeft(2, '0')}.${quest.createdAt!.month.toString().padLeft(2, '0')}.${quest.createdAt!.year}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (quest.isCompleted && quest.completedAt != null)
                        Text(
                          'Completed: ${quest.completedAt!.day.toString().padLeft(2, '0')}.${quest.completedAt!.month.toString().padLeft(2, '0')}.${quest.completedAt!.year}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.greenAccent),
                        ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  if (onComplete != null && !quest.isCompleted)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onComplete!();
                      },
                    ),
                  TextButton(
                    child: const Text('Close'),
                    onPressed: () => Navigator.of(ctx).pop(),
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
                        Icon(
                          quest.type.icon,
                          color: theme.textTheme.titleMedium?.color,
                          size: 20,
                        ),
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
                      color: difficultyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: difficultyColor, width: 1),
                    ),
                    child: Text(
                      quest.difficulty.name,
                      style: TextStyle(
                        color: difficultyColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
                    '+${quest.xpReward} XP',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (onComplete != null && !quest.isCompleted)
                    ElevatedButton(
                      onPressed: onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text('Complete'),
                    ),
                  if (quest.isCompleted)
                    const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

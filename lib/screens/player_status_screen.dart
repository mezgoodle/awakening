import 'package:awakening/providers/system_log_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_provider.dart';
import '../providers/player_provider.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';
import '../widgets/active_buff_chip.dart';
import 'system_log_screen.dart';

class PlayerStatusScreen extends StatefulWidget {
  const PlayerStatusScreen({super.key});

  @override
  State<PlayerStatusScreen> createState() => _PlayerStatusScreenState();
}

class _PlayerStatusScreenState extends State<PlayerStatusScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _showLevelUpSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'РІВЕНЬ ПІДВИЩЕНО! Вітаємо, Мисливець!',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer),
        ),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Функція для показу діалогу редагування імені
  Future<void> _showEditNameDialog(
      BuildContext context, PlayerProvider playerProvider) async {
    final TextEditingController nameController =
        TextEditingController(text: playerProvider.player.playerName);
    final formKey = GlobalKey<FormState>(); // Для валідації

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Користувач має натиснути кнопку
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Змінити ім\'я гравця'),
          content: SingleChildScrollView(
            // На випадок, якщо екран малий
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                autofocus: true,
                decoration:
                    const InputDecoration(hintText: "Введіть нове ім'я"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ім\'я не може бути порожнім';
                  }
                  if (value.trim().length > 20) {
                    // Обмеження довжини
                    return 'Ім\'я занадто довге (макс. 20 символів)';
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Скасувати'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Зберегти'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  playerProvider.setPlayerName(nameController.text.trim());
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ім\'я гравця оновлено!')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Додамо метод для отримання кольору рангу, схожий на той, що в QuestCard
  Color _getRankColor(QuestDifficulty difficulty, BuildContext context) {
    // Можна винести цю логіку в утиліту або в QuestModel, якщо вона використовується в багатьох місцях
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
      default:
        return Colors.grey[700]!;
    }
  }

  Widget _buildResourceBar(String label, int currentValue, int maxValue,
      Color barColor, IconData icon) {
    double percentage =
        maxValue > 0 ? (currentValue / maxValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: barColor, size: 18),
            const SizedBox(width: 8),
            Text(
              '$label: $currentValue / $maxValue',
              style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          // Контейнер для рамки прогрес-бару
          height: 12, // Висота бару
          decoration: BoxDecoration(
            color: Colors.grey[800], // Фон бару
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[700]!, width: 1),
          ),
          child: FractionallySizedBox(
            // Для заповнення частини бару
            widthFactor: percentage,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final questProvider = context.read<QuestProvider>();
    final systemLogProvider = context.read<SystemLogProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (playerProvider.justLeveledUp && mounted) {
        _showLevelUpSnackBar(context);
      }
    });

    if (playerProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Статус Гравця'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final player = playerProvider.player;

    final finalStats = playerProvider.finalStats;
    final finalMaxHp = playerProvider.finalMaxHp;
    final finalMaxMp = playerProvider.finalMaxMp;

    QuestDifficulty nextPotentialRankByLevel =
        PlayerModel.calculateRankByLevel(player.level);
    bool canChallengeNextRank =
        nextPotentialRankByLevel.index > player.playerRank.index &&
            !questProvider.activeQuests
                .any((q) => q.type == QuestType.rankUpChallenge);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статус Гравця'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Журнал Системи',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const SystemLogScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Скинути прогрес (Тест)',
            onPressed: () async {
              // Запитуємо підтвердження перед скиданням
              bool? confirmReset = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Скинути Прогрес?'),
                    content: const Text(
                        'Ви впевнені, що хочете скинути весь прогрес гравця? Цю дію неможливо буде скасувати.'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Скасувати'),
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                      ),
                      TextButton(
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Скинути'),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ],
                  );
                },
              );
              if (confirmReset == true) {
                await playerProvider.resetPlayerData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Прогрес гравця скинуто.')),
                  );
                }
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            _buildInfoCard(
              'Ім\'я Гравця:',
              player.playerName,
              actionWidget: IconButton(
                // Додаємо кнопку редагування
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white70, size: 20),
                tooltip: 'Редагувати ім\'я',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _showEditNameDialog(context, playerProvider);
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF2A2A2A),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text("Ранг Мисливця:",
                        style: TextStyle(fontSize: 16, color: Colors.white70)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: _getRankColor(player.playerRank, context)
                              .withOpacity(0.25),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: _getRankColor(player.playerRank, context),
                              width: 1.5)),
                      child: Text(
                        QuestModel.getQuestDifficultyName(player
                            .playerRank), // Використовуємо той самий метод
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getRankColor(player.playerRank, context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildInfoCard('Рівень:', '${player.level}'),
            const SizedBox(height: 16),
            _buildActiveBuffsSection(player),
            const SizedBox(height: 16),
            _buildResourceBar("HP", player.currentHp, finalMaxHp,
                Colors.redAccent[400]!, Icons.favorite_rounded),
            const SizedBox(height: 12),
            _buildResourceBar("MP", player.currentMp, finalMaxMp,
                Colors.blueAccent[400]!, Icons.flash_on_rounded),
            const SizedBox(height: 20),
            Text(
              'Досвід: ${player.xp} / ${player.xpToNextLevel}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (player.xpToNextLevel > 0)
                  ? (player.xp / player.xpToNextLevel).clamp(0.0, 1.0)
                  : 0.0,
              backgroundColor: Colors.grey[700],
            ),
            const SizedBox(height: 24),
            Text(
              'Характеристики:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (player.availableStatPoints > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Доступні очки для розподілу: ${player.availableStatPoints}',
                  style: TextStyle(
                      color: Colors.lightBlueAccent[100], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
            ...finalStats.entries.map((entry) {
              final baseValue = player.stats[entry.key] ?? 0;
              final finalValue = entry.value;
              final bonus = finalValue - baseValue;
              final slog = context.read<SystemLogProvider>();
              return _buildStatRow(
                PlayerModel.getStatName(entry.key),
                entry.value,
                context,
                bonus: bonus,
                canIncrease: true,
                onIncrease: () {
                  playerProvider.spendStatPoint(entry.key, 1, slog);
                },
              );
            }).toList(),
            const SizedBox(height: 30),
            if (canChallengeNextRank)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(
                      'Запросити Випробування на ${QuestModel.getQuestDifficultyName(QuestDifficulty.values[player.playerRank.index + 1])}-Ранг'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[400],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: questProvider.isGeneratingQuest
                      ? null
                      : () async {
                          bool requested =
                              await playerProvider.requestRankUpChallenge(
                                  questProvider,
                                  systemLogProvider,
                                  playerProvider);
                          if (requested && context.mounted) {
                            // Повідомлення про запит вже є в requestRankUpChallenge
                            // Можна оновити екран, щоб кнопка зникла, якщо квест додано
                          }
                        },
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.amberAccent, // Змінимо колір для різноманітності
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final slog = context.read<SystemLogProvider>();
                playerProvider.addXp(250, slog); // Додаємо 50 XP для тесту
              },
              child: const Text('Додати 250 XP (Тест)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBuffsSection(PlayerModel player) {
    if (player.activeBuffs.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> buffWidgets = player.activeBuffs.entries.map((entry) {
      return ActiveBuffChip(
        key: ValueKey(entry.key),
        skillId: entry.key,
        endTimeString: entry.value,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активні Ефекти:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: buffWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, {Widget? actionWidget}) {
    return Card(
      color: const Color(0xFF2A2A2A),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label,
                style: const TextStyle(fontSize: 16, color: Colors.white70)),
            Row(
              // Об'єднуємо значення та екшн-віджет
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                if (actionWidget != null) ...[
                  // Якщо є actionWidget
                  const SizedBox(width: 8),
                  actionWidget,
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String statName, int statValue, BuildContext context,
      {int bonus = 0, bool canIncrease = false, VoidCallback? onIncrease}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('$statName:',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 16)),
          Row(
            children: [
              Text('$statValue',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
              if (bonus > 0)
                Text(
                  ' (+$bonus)',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent[400]),
                ),
              if (canIncrease && onIncrease != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        color: Colors.lightBlueAccent[100]),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Збільшити ${statName.toLowerCase()}',
                    onPressed: onIncrease,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

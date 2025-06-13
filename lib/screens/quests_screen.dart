// lib/screens/quests_screen.dart
import 'package:awakening/models/player_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_provider.dart';
import '../providers/player_provider.dart';
import '../models/quest_model.dart';
import '../widgets/quest_card.dart'; // Створимо цей віджет наступним

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Можна викликати generateDailyQuestsIfNeeded тут, якщо ще не викликали в HomeScreen
    // або якщо хочемо оновлювати при кожному відкритті вкладки (не дуже добре для щоденних)
    // final playerProvider = context.read<PlayerProvider>();
    // if (!playerProvider.isLoading) {
    //   context.read<QuestProvider>().generateDailyQuestsIfNeeded(playerProvider);
    // }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questProvider = context.watch<QuestProvider>();
    final playerProvider = context
        .read<PlayerProvider>(); // read, бо використовуємо тільки для дії

    if (questProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Завдання')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Завдання'),
        actions: [
          // Кнопка для генерації щоденних квестів (для тесту)
          IconButton(
            icon: const Icon(Icons.wb_sunny_outlined),
            tooltip: 'Згенерувати щоденні завдання',
            onPressed: () {
              if (!playerProvider.isLoading) {
                // Перевіряємо чи дані гравця завантажені
                questProvider.generateDailyQuestsIfNeeded(playerProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Спроба генерації щоденних завдань...')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Дані гравця ще завантажуються. Спробуйте пізніше.')),
                );
              }
            },
          ),
          // Кнопка для скидання всіх квестів (для тесту)
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Скинути всі завдання (Тест)',
            onPressed: () async {
              bool? confirmReset = await showDialog<bool>(
                context: context,
                builder: (BuildContext ctx) {
                  return AlertDialog(
                    title: const Text('Скинути Завдання?'),
                    content: const Text(
                        'Ви впевнені, що хочете скинути всі активні та виконані завдання?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Скасувати'),
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      TextButton(
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Скинути'),
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  );
                },
              );
              if (confirmReset == true) {
                await questProvider.resetAllQuests();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Всі завдання скинуто.')),
                  );
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.lightBlueAccent,
          labelColor: Colors.lightBlueAccent,
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(text: 'Активні'),
            Tab(text: 'Виконані'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestList(
              context, questProvider.activeQuests, playerProvider, true),
          _buildQuestList(
              context, questProvider.completedQuests, playerProvider, false),
        ],
      ),
      // TODO: Кнопка для генерації нового завдання через Gemini (Фаза 3)
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                // Тут буде логіка генерації завдання через Gemini API
                // Поки що можемо додати тестовий квест
                final testQuest = QuestModel(
                    title: "Тестове Згенероване Завдання",
                    description:
                        "Це завдання було додано для тестування кнопки.",
                    xpReward: 50,
                    difficulty: QuestDifficulty.C,
                    type: QuestType.generated, // або milestone
                    statRewards: {PlayerStat.agility: 1});
                questProvider.addQuest(testQuest);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Додано тестове завдання: ${testQuest.title}')),
                );
              },
              label: const Text('Нове завдання'),
              icon: const Icon(Icons.add_task_sharp),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            )
          : null,
    );
  }

  Widget _buildQuestList(BuildContext context, List<QuestModel> quests,
      PlayerProvider playerProvider, bool isActiveList) {
    if (quests.isEmpty) {
      return Center(
        child: Text(
          isActiveList
              ? 'Немає активних завдань.\nСпробуйте згенерувати щоденні або додати нове!'
              : 'Ще немає виконаних завдань.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
        ),
      );
    }

    // Сортуємо: щоденні спочатку, потім за складністю (S -> F), потім за датою створення
    quests.sort((a, b) {
      if (a.type == QuestType.daily && b.type != QuestType.daily) return -1;
      if (a.type != QuestType.daily && b.type == QuestType.daily) return 1;
      int difficultyCompare = b.difficulty.index
          .compareTo(a.difficulty.index); // S (більший індекс) йде першим
      if (difficultyCompare != 0) return difficultyCompare;
      return (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)); // Новіші спочатку
    });

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        return QuestCard(
          quest: quest,
          onComplete: isActiveList
              ? () {
                  // Показати діалог підтвердження
                  showDialog(
                      context: context,
                      builder: (BuildContext ctx) {
                        return AlertDialog(
                          title: Text('Завершити завдання "${quest.title}"?'),
                          content: Text(
                              'Ви дійсно виконали це завдання?\nНагорода: ${quest.xpReward} XP' +
                                  (quest.statRewards != null &&
                                          quest.statRewards!.isNotEmpty
                                      ? '\nХарактеристики: ${quest.statRewards!.entries.map((e) => '${PlayerModel.getStatName(e.key)} +${e.value}').join(', ')}'
                                      : '')),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Скасувати'),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                            ElevatedButton(
                              child: const Text('Завершити'),
                              onPressed: () {
                                context
                                    .read<QuestProvider>()
                                    .completeQuest(quest.id, playerProvider);
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Завдання "${quest.title}" виконано!'),
                                      backgroundColor: Colors.green[700]),
                                );
                              },
                            ),
                          ],
                        );
                      });
                }
              : null, // Немає дії для виконаних
        );
      },
    );
  }
}

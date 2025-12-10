import 'package:awakening/models/player_model.dart';
import 'package:awakening/providers/item_provider.dart';
import 'package:awakening/providers/system_log_provider.dart';
import 'package:awakening/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_provider.dart';
import '../providers/player_provider.dart';
import '../models/quest_model.dart';
import '../widgets/quest_card.dart';
import 'system_log_screen.dart';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _showQuestGenerationOptionsDialog(
      BuildContext context) async {
    PlayerStat? selectedStat;
    final List<DropdownMenuItem<PlayerStat?>> statItems = [
      const DropdownMenuItem<PlayerStat?>(
        value: null,
        child: Text('Any / General'),
      ),
      ...PlayerStat.values.map((PlayerStat stat) {
        return DropdownMenuItem<PlayerStat?>(
          value: stat,
          child: Text(PlayerModel.getStatName(stat)),
        );
      }).toList(),
    ];

    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Quest Generation Options'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<PlayerStat?>(
                    decoration: const InputDecoration(
                      labelText: 'Focus Stat',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedStat,
                    items: statItems,
                    onChanged: (PlayerStat? newValue) {
                      setStateDialog(() {
                        selectedStat = newValue;
                      });
                    },
                    hint: const Text('Select stat (optional)'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(null);
                },
              ),
              ElevatedButton(
                child: const Text('Generate'),
                onPressed: () {
                  Navigator.of(dialogContext).pop({
                    'targetStat': selectedStat,
                  });
                },
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _generateNewQuest() async {
    final playerProvider = context.read<PlayerProvider>();
    final questProvider = context.read<QuestProvider>();

    if (playerProvider.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Player data is still loading. Please try later.')),
      );
      return;
    }
    if (questProvider.isGeneratingQuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Quest is already generating... Please wait.')),
      );
      return;
    }

    final generationParams = await _showQuestGenerationOptionsDialog(context);

    if (generationParams == null) {
      return;
    }

    final PlayerStat? targetStat =
        generationParams['targetStat'] as PlayerStat?;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          duration: Duration(seconds: 10),
          content: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 15),
            Text('Generating quest via Gemini...')
          ])),
    );
    final slog = context.read<SystemLogProvider>();

    final itemProvider = context.read<ItemProvider>();

    QuestModel? generatedQuest = await questProvider.fetchAndAddGeneratedQuest(
        playerProvider: playerProvider,
        targetStat: targetStat, // Якщо буде вибір
        slog: slog,
        itemProvider: itemProvider
        // customInstruction: customInstruction?.isNotEmpty == true ? customInstruction : null,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (generatedQuest != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'New quest "${generatedQuest.title}" generated and added!'),
            backgroundColor: Colors.green[700],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate quest. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questProvider = context.watch<QuestProvider>();
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (questProvider.isLoading && !questProvider.isGeneratingQuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Завдання')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'System Log',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const SystemLogScreen()),
              );
            },
          ),
          Consumer<PlayerProvider>(
              builder: (context, playerProviderInstance, child) {
            return IconButton(
              icon: const Icon(Icons.wb_sunny_outlined),
              tooltip: 'Generate daily quests',
              onPressed: (questProvider.isGeneratingQuest ||
                      playerProviderInstance.isLoading)
                  ? null
                  : () {
                      final slog = context.read<SystemLogProvider>();
                      questProvider.generateDailyQuestsIfNeeded(
                          playerProviderInstance, slog);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Attempting to generate daily quests...')),
                      );
                    },
            );
          }),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Reset all quests (Test)',
            onPressed: questProvider.isGeneratingQuest
                ? null
                : () async {
                    bool? confirmReset = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext ctx) {
                        return AlertDialog(
                          title: const Text('Reset Quests?'),
                          content: const Text(
                              'Are you sure you want to reset all active and completed quests?'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(ctx).pop(false),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Reset'),
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
                          const SnackBar(content: Text('All quests reset.')),
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
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestList(context, questProvider.activeQuests, true),
          _buildQuestList(context, questProvider.completedQuests, false),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed:
                  questProvider.isGeneratingQuest ? null : _generateNewQuest,
              label: questProvider.isGeneratingQuest
                  ? const Text('Generating...')
                  : const Text('New Quest'),
              icon: questProvider.isGeneratingQuest
                  ? Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black54),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              backgroundColor: questProvider.isGeneratingQuest
                  ? Colors.grey
                  : Theme.of(context).colorScheme.secondaryContainer,
            )
          : null,
    );
  }

  Widget _buildQuestList(
      BuildContext context, List<QuestModel> quests, bool isActiveList) {
    final playerProvider = context.read<PlayerProvider>();
    if (quests.isEmpty) {
      return Center(
        child: Text(
          isActiveList
              ? 'No active quests.\nTry generating daily quests or add a new one!'
              : 'No completed quests yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
        ),
      );
    }

    quests.sort((a, b) {
      if (a.type == QuestType.daily && b.type != QuestType.daily) return -1;
      if (a.type != QuestType.daily && b.type == QuestType.daily) return 1;
      int difficultyCompare = b.difficulty.index.compareTo(a.difficulty.index);
      if (difficultyCompare != 0) return difficultyCompare;
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
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
                  showDialog(
                      context: context,
                      builder: (BuildContext ctx) {
                        return AlertDialog(
                          title: Text('Complete quest "${quest.title}"?'),
                          content: Text(
                              'Have you really completed this quest?\nReward: ${quest.xpReward} XP'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                            ElevatedButton(
                              child: const Text('Complete'),
                              onPressed: () {
                                final slog = context.read<SystemLogProvider>();
                                context.read<QuestProvider>().completeQuest(
                                    quest.id, playerProvider, slog);
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Quest "${quest.title}" completed!'),
                                      backgroundColor: Colors.green[700]),
                                );
                              },
                            ),
                          ],
                        );
                      });
                }
              : null,
        );
      },
    );
  }
}

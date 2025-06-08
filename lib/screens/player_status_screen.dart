// lib/screens/player_status_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../models/player_model.dart';

class PlayerStatusScreen extends StatefulWidget {
  const PlayerStatusScreen({super.key});

  @override
  State<PlayerStatusScreen> createState() => _PlayerStatusScreenState();
}

class _PlayerStatusScreenState extends State<PlayerStatusScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Слухаємо зміни в PlayerProvider, щоб показати SnackBar
    // Використовуємо context.read() тут, щоб не викликати перебудову при кожній зміні,
    // а лише один раз підписатися на _justLeveledUp.
    // Краще це робити через Listener або інший підхід, але для простоти поки так.
    // Більш правильний підхід - це мати окремий віджет, який слухає specifically _justLeveledUp.
    // Або передавати callback з provider.

    // Оновлення: Краще використовувати context.watch і перевіряти _justLeveledUp в build.
    // Але щоб SnackBar показувався лише один раз, ми можемо використати addPostFrameCallback
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

  @override
  Widget build(BuildContext context) {
    // Використовуємо Selector для перебудови лише при зміні конкретних полів, якщо потрібно оптимізувати
    // Або context.watch для простоти
    final playerProvider = context.watch<PlayerProvider>();

    // Перевірка на підвищення рівня і показ SnackBar
    // WidgetsBinding.instance.addPostFrameCallback гарантує, що SnackBar
    // показується після того, як фрейм вже побудований.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (playerProvider.justLeveledUp && mounted) {
        // mounted - перевірка, що віджет ще в дереві
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статус Гравця'),
        actions: [
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
            _buildInfoCard('Ім\'я Гравця:', player.playerName),
            // TODO: Додати можливість змінювати ім'я гравця
            const SizedBox(height: 16),
            _buildInfoCard('Рівень:', '${player.level}'),
            const SizedBox(height: 8),
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
            ...player.stats.entries.map((entry) {
              return _buildStatRow(
                PlayerModel.getStatName(entry.key),
                entry.value,
                context,
                canIncrease: player.availableStatPoints > 0,
                onIncrease: () {
                  playerProvider.increaseStat(entry.key, 1);
                },
              );
            }).toList(),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.amberAccent, // Змінимо колір для різноманітності
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                playerProvider.addXp(50); // Додаємо 50 XP для тесту
              },
              child: const Text('Додати 50 XP (Тест)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      color: const Color(0xFF2A2A2A),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label,
                style: const TextStyle(fontSize: 16, color: Colors.white70)),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String statName, int statValue, BuildContext context,
      {bool canIncrease = false, VoidCallback? onIncrease}) {
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
              if (canIncrease && onIncrease != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        color: Colors.lightBlueAccent[100]),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(), // щоб іконка була маленькою
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

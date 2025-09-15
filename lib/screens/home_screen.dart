import 'package:awakening/screens/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'player_status_screen.dart';
import 'quests_screen.dart';
import 'skills_screen.dart';
import '../providers/quest_provider.dart';
import '../providers/player_provider.dart';
import '../providers/system_log_provider.dart';
import '../utils/ui_helpers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const PlayerStatusScreen(),
    const QuestsScreen(),
    const SkillsScreen(),
    const InventoryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // Викликаємо генерацію щоденних квестів при ініціалізації HomeScreen
    // Це краще місце, ніж main.dart -> MyApp build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Використовуємо context.read для одноразового виклику
      final playerProvider = context.read<PlayerProvider>();
      final slog = context.read<SystemLogProvider>();
      // Переконуємось, що дані гравця завантажені перед генерацією квестів,
      // щоб квести могли базуватись на рівні гравця.
      if (!playerProvider.isLoading) {
        context
            .read<QuestProvider>()
            .generateDailyQuestsIfNeeded(playerProvider, slog);
      } else {
        // Якщо дані ще завантажуються, можна додати слухача, щоб викликати після завантаження
        // Або покластися на те, що generateDailyQuestsIfNeeded буде викликано при першому
        // відкритті вкладки квестів, якщо там є така логіка.
        // Простіший варіант: користувач сам перейде на вкладку квестів, і там це обробиться.
        // Або, якщо generateDailyQuestsIfNeeded може безпечно працювати з дефолтним PlayerModel,
        // то можна викликати одразу. Наш поточний PlayerProvider ініціалізується з дефолтним
        // PlayerModel, тому це має бути безпечно.
        // Однак, playerProvider.player.level буде 1, якщо дані ще не завантажені.
        // Тому краще дочекатися.

        // Слухач для playerProvider.isLoading
        // Цей підхід може бути складним, якщо PlayerProvider не повідомляє про закінчення завантаження
        // так, щоб це легко було відловити тут.
        // Альтернатива: викликати в `QuestsScreen` в `initState` або при першому білді.
        // Або зробити `PlayerProvider` таким, що він повертає Future при ініціалізації.

        // Найпростіше: якщо generateDailyQuestsIfNeeded викликається з QuestProvider.isLoading == false,
        // то playerProvider теж вже має бути завантажений.
        // Тому що QuestProvider викликає _loadQuests(), який асинхронний.
        // А PlayerProvider викликає _loadPlayerData(), який теж асинхронний.
        // Вони працюють паралельно.
        // Ми можемо дочекатися завантаження обох провайдерів.
        // АБО, як я зробив у QuestProvider, передавати PlayerProvider як аргумент
        // і використовувати вже завантажені дані гравця.
        // Наш PlayerProvider має _isLoading, тому це ОК.
        // Поточна логіка в QuestProvider вже використовує переданий playerProvider.

        // Проблема: PlayerProvider може ще завантажувати дані, коли ми викликаємо generateDailyQuestsIfNeeded.
        // Рішення: зробимо PlayerProvider "готовим" після _loadPlayerData.
        // `generateDailyQuestsIfNeeded` приймає `playerProvider`.
        // Усередині `generateDailyQuestsIfNeeded` ми використовуємо `playerProvider.player.level`.
        // Якщо `playerProvider` ще `isLoading`, то `player.level` буде дефолтним (1).

        // Кращий підхід:
        _initDailyQuests();
      }
    });
    final systemLogProvider = context.read<SystemLogProvider>();
    systemLogProvider.addListener(_showLatestSystemMessage);
  }

  @override
  void dispose() {
    context.read<SystemLogProvider>().removeListener(_showLatestSystemMessage);
    super.dispose();
  }

  void _showLatestSystemMessage() {
    final systemLogProvider = context.read<SystemLogProvider>();
    final message = systemLogProvider
        .latestMessageForSnackbar; // Це скине повідомлення в провайдері
    if (message != null && mounted) {
      // Відкладаємо показ SnackBar, щоб уникнути помилок під час build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Перевіряємо ще раз
          showSystemSnackBar(context, message);
        }
      });
    }
  }

  Future<void> _initDailyQuests() async {
    final playerProvider = context.read<PlayerProvider>();
    final slog = context.read<SystemLogProvider>();

    if (!playerProvider.isLoading) {
      await context
          .read<QuestProvider>()
          .generateDailyQuestsIfNeeded(playerProvider, slog);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person_search_outlined),
            activeIcon: Icon(Icons.person_search),
            label: 'Статус',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Завдання',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_purple500_outlined),
            activeIcon: Icon(Icons.star_purple500),
            label: 'Навички',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Інвентар',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

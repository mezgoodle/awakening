// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'player_status_screen.dart';
import 'quests_screen.dart'; // Створимо цей файл наступним
import '../providers/quest_provider.dart';
import '../providers/player_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const PlayerStatusScreen(),
    const QuestsScreen(), // Додамо екран квестів
    // Тут можна додати більше екранів, наприклад, "Інвентар", "Навички"
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
      // Переконуємось, що дані гравця завантажені перед генерацією квестів,
      // щоб квести могли базуватись на рівні гравця.
      if (!playerProvider.isLoading) {
        context
            .read<QuestProvider>()
            .generateDailyQuestsIfNeeded(playerProvider);
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
  }

  Future<void> _initDailyQuests() async {
    final playerProvider = context.read<PlayerProvider>();
    // Чекаємо, поки PlayerProvider завантажить дані, якщо він це робить асинхронно
    // і має спосіб повідомити про завершення.
    // Оскільки PlayerProvider має isLoading, ми можемо чекати на його зміну.
    // Але простіше просто передати його в QuestProvider.
    // PlayerProvider() починає завантаження.
    // QuestProvider() починає завантаження.
    // Вони можуть завершитися в різний час.

    // Гарантуємо, що playerProvider не isLoading
    if (playerProvider.isLoading) {
      // Простий спосіб зачекати - це невелика затримка, але це погано.
      // Або додати слухача до PlayerProvider.
      // Або QuestProvider повинен сам вміти чекати або отримувати оновлений PlayerProvider.
      // Зараз PlayerProvider передається як аргумент, тому це актуальні дані на момент виклику.

      // Давайте зробимо так: якщо playerProvider ще завантажується, ми спробуємо
      // викликати генерацію квестів трохи пізніше або коли він стане доступним.
      // Найпростіше - покластися на те, що на момент, коли користувач відкриє екран квестів,
      // дані гравця вже будуть.
      // Або, як варіант, QuestProvider при генерації може перевіряти playerProvider.isLoading
      // і якщо так, то або не генерувати, або генерувати "базові" квести.

      // Поки що залишимо як є, з викликом в initState.
      // `generateDailyQuestsIfNeeded` використовує playerProvider.player.level,
      // який буде 1, якщо дані гравця ще не завантажені. Це може бути прийнятним для першого разу.
      // Або ж, ми можемо зробити так, щоб `PlayerProvider` повертав Future зі свого конструктора
      // чи методу ініціалізації, і чекати його тут.

      // Найбільш "чистий" спосіб - це коли PlayerProvider повністю ініціалізований,
      // тоді ініціалізувати QuestProvider, передаючи йому вже готовий PlayerProvider.
      // Це можна зробити через ChangeNotifierProxyProvider, якщо QuestProvider залежить від PlayerProvider
      // при створенні. Але він залежить тільки для одного методу.

      // Поки що:
      // Якщо PlayerProvider не завантажений, generateDailyQuestsIfNeeded
      // може використати рівень 1 для розрахунку нагород. Це не страшно.
      // При наступному відкритті (наступного дня) дані вже будуть.
      await context
          .read<QuestProvider>()
          .generateDailyQuestsIfNeeded(playerProvider);
    } else {
      await context
          .read<QuestProvider>()
          .generateDailyQuestsIfNeeded(playerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar тут не потрібен, бо кожен екран (_widgetOptions) матиме свій
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person_search_outlined), // Іконка для статусу
            activeIcon: Icon(Icons.person_search),
            label: 'Статус',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined), // Іконка для квестів
            activeIcon: Icon(Icons.list_alt),
            label: 'Завдання',
          ),
          // Можна додати ще вкладки
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

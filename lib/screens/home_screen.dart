import 'package:awakening/screens/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'player_status_screen.dart';
import 'quests_screen.dart';
import 'skills_screen.dart';
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
    final message = systemLogProvider.latestMessageForSnackbar;
    if (message != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showSystemSnackBar(context, message);
        }
      });
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
            label: 'Status',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Quests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_purple500_outlined),
            activeIcon: Icon(Icons.star_purple500),
            label: 'Skills',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

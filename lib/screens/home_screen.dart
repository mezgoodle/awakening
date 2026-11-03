import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'inventory_screen.dart';
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
  StreamSubscription? _snackbarSubscription;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final systemLogProvider = context.read<SystemLogProvider>();
      _snackbarSubscription =
          systemLogProvider.snackbarStream.listen((message) {
        if (mounted) {
          showSystemSnackBar(context, message);
        }
      });
    });
  }

  @override
  void dispose() {
    _snackbarSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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

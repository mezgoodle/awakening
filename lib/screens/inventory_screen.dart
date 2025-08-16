import 'package:awakening/providers/theme_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item_model.dart';
import '../providers/player_provider.dart';
import '../providers/item_provider.dart';
import '../providers/system_log_provider.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final itemProvider = context.watch<ItemProvider>();
    final slog = context.read<SystemLogProvider>();

    if (playerProvider.isLoading || itemProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Інвентар')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final List<InventoryItem> inventoryItems = playerProvider.player.inventory
        .map((itemData) =>
            InventoryItem.fromJson(itemData, itemProvider.itemDictionary))
        .toList();
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Інвентар'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: inventoryItems.isEmpty
          ? const Center(child: Text('Ваш інвентар порожній.'))
          : GridView.builder(
              padding: const EdgeInsets.all(12.0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120.0,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio: 0.8,
              ),
              itemCount: inventoryItems.length,
              itemBuilder: (context, index) {
                final item = inventoryItems[index];
                return InventorySlot(
                    item: item,
                    onUse: () {
                      playerProvider.useItem(item.itemId, slog);
                    });
              },
            ),
    );
  }
}

class InventorySlot extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onUse;

  const InventorySlot({super.key, required this.item, required this.onUse});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Показати діалог з деталями та кнопкою "Використати"
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(item.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Тут можна буде додати іконку
                Text(item.description),
                const SizedBox(height: 10),
                Text('Кількість: ${item.quantity}'),
              ],
            ),
            actions: [
              if (item.type == ItemType.potion)
                TextButton(
                  onPressed: () {
                    onUse();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Використати'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Закрити'),
              ),
            ],
          ),
        );
      },
      child: Card(
        color: Colors.white10,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: Colors.white24, width: 0.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildItemIcon(item.iconPath),
              ),
            ),
            if (item.isStackable && item.quantity > 0)
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemIcon(String iconPath) {
    if (iconPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        iconPath,
        placeholderBuilder: (context) => const Icon(Icons.inventory_2_outlined,
            size: 32, color: Colors.grey),
      );
    } else {
      return Image.asset(
        iconPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.error_outline,
              size: 32, color: Colors.redAccent);
        },
      );
    }
  }
}

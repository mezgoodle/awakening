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
    final itemProvider = context.read<ItemProvider>();
    final slog = context.read<SystemLogProvider>();

    // Конвертуємо дані з інвентарю гравця в повноцінні об'єкти InventoryItem
    final List<InventoryItem> inventoryItems = playerProvider.player.inventory
        .map((itemData) =>
            InventoryItem.fromJson(itemData, itemProvider.itemDictionary))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Інвентар'),
      ),
      body: inventoryItems.isEmpty
          ? const Center(child: Text('Ваш інвентар порожній.'))
          : GridView.builder(
              padding: const EdgeInsets.all(12.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 4 предмети в ряд
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8, // Співвідношення сторін комірки
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
        child: Stack(
          children: [
            const Center(
              // TODO: Додати іконку предмета
              child: Icon(Icons.local_drink, size: 32, color: Colors.redAccent),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Text(
                'x${item.quantity}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

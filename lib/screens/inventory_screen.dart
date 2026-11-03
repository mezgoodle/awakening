import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item_model.dart';
import '../providers/player_provider.dart';
import '../providers/item_provider.dart';
import '../providers/system_log_provider.dart';
import '../providers/theme_provider.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final itemProvider = context.watch<ItemProvider>();
    final slog = context.read<SystemLogProvider>();

    if (playerProvider.isLoading || itemProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final List<InventoryItem> inventoryItems = playerProvider.player.inventory
        .map((entry) {
          final template = itemProvider.getItemById(entry.itemId);
          if (template != null) {
            return template.copyWith(quantity: entry.quantity);
          }
          return InventoryItem(
            itemId: entry.itemId,
            name: entry.itemId,
            description: 'Item details unavailable in local catalog.',
            type: ItemType.collectible,
            iconPath: 'assets/icons/items/unknown.svg',
            quantity: entry.quantity,
          );
        })
        .toList();

    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            tooltip: 'Toggle Theme',
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: inventoryItems.isEmpty
          ? const Center(
              child: Text(
                'Inventory is empty.\nComplete quests to obtain potions and materials.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12.0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120.0,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio: 0.85,
              ),
              itemCount: inventoryItems.length,
              itemBuilder: (context, index) {
                final item = inventoryItems[index];
                return InventorySlot(
                  item: item,
                  onUse: () {
                    playerProvider.useItem(item.itemId, slog);
                  },
                );
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
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(item.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description),
                const SizedBox(height: 10),
                if (item.effectsSummary.isNotEmpty) ...[
                  Text(
                    'Effect: ${item.effectsSummary}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Quantity: ${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              if (item.type == ItemType.potion)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onUse();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Use Potion'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
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
            if (item.isStackable && item.quantity > 1)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
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
    if (iconPath.trim().isEmpty) {
      return const Icon(
        Icons.inventory_2_outlined,
        size: 44,
        color: Colors.grey,
      );
    }
    final lower = iconPath.toLowerCase();
    if (lower.endsWith('.svg')) {
      return SvgPicture.asset(
        iconPath,
        placeholderBuilder: (context) => const Icon(
          Icons.inventory_2_outlined,
          size: 32,
          color: Colors.grey,
        ),
      );
    } else {
      return Image.asset(
        iconPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.inventory_2_outlined,
            size: 32,
            color: Colors.grey,
          );
        },
      );
    }
  }
}

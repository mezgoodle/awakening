import 'package:flutter/foundation.dart';
import '../models/inventory_item_model.dart';

class ItemProvider with ChangeNotifier {
  final Map<String, InventoryItem> _itemDictionary = {
    InventoryItem.smallHealthPotionId: InventoryItem(
      itemId: InventoryItem.smallHealthPotionId,
      name: 'Мале Зілля Здоров\'я',
      description: 'Відновлює невелику кількість здоров\'я.',
      type: ItemType.potion,
      iconPath: 'assets/icons/items/health_potion.svg',
      isStackable: true,
      effects: {ItemEffectType.restoreHp: 25.0},
    ),
    // Тут можна буде додавати інші предмети
  };

  Map<String, InventoryItem> get itemDictionary => _itemDictionary;

  InventoryItem? getItemById(String itemId) {
    return _itemDictionary[itemId];
  }
}

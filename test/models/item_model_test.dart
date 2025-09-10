import 'package:flutter_test/flutter_test.dart';
import 'package:awakening/models/item_model.dart';

void main() {
  group('InventoryItem', () {
    final mockItemDictionary = {
      'potion_health_small': InventoryItem(
        itemId: 'potion_health_small',
        name: 'Small Health Potion',
        description: 'Restores a small amount of HP.',
        type: ItemType.potion,
        iconPath: 'assets/icons/items/potion_health_small.svg',
        quantity: 1,
        effects: {ItemEffectType.restoreHp: 50},
      ),
    };

    test('copyWith creates a copy with updated quantity', () {
      final item = mockItemDictionary['potion_health_small']!;
      final copiedItem = item.copyWith(quantity: 5);

      expect(copiedItem.quantity, 5);
      expect(copiedItem.itemId, item.itemId);
      expect(copiedItem.name, item.name);
    });

    test('addQuantity increases the quantity', () {
      final item = mockItemDictionary['potion_health_small']!;
      final newItem = item.addQuantity(5);

      expect(newItem.quantity, 6);
    });

    test('removeQuantity decreases the quantity', () {
      final item = mockItemDictionary['potion_health_small']!.copyWith(quantity: 10);
      final newItem = item.removeQuantity(5);

      expect(newItem.quantity, 5);
    });

    test('removeQuantity does not go below zero', () {
      final item = mockItemDictionary['potion_health_small']!;
      final newItem = item.removeQuantity(5);

      expect(newItem.quantity, 0);
    });

    test('toJson returns the correct map', () {
      final item = mockItemDictionary['potion_health_small']!.copyWith(quantity: 3);
      final json = item.toJson();

      expect(json, {'itemId': 'potion_health_small', 'quantity': 3});
    });

    test('fromJson creates the correct item from map', () {
      final json = {'itemId': 'potion_health_small', 'quantity': 5};
      final item = InventoryItem.fromJson(json, mockItemDictionary);

      expect(item.quantity, 5);
      expect(item.itemId, 'potion_health_small');
      expect(item.name, 'Small Health Potion');
    });

    test('fromJson handles unknown items', () {
      final json = {'itemId': 'unknown_item', 'quantity': 2};
      final item = InventoryItem.fromJson(json, mockItemDictionary);

      expect(item.quantity, 2);
      expect(item.itemId, 'unknown_item');
      expect(item.name, 'Невідомий Предмет');
    });
  });
}

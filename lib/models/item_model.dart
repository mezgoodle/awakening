enum ItemType {
  potion, // Зілля (витратний матеріал)
  key, // Ключ (для підземель)
  material, // Матеріал для крафту
  equipment, // Екіпірування
  collectible, // Колекційний предмет
}

enum ItemEffectType {
  restoreHp, // Відновити фіксовану кількість HP
  restoreMp, // Відновити фіксовану кількість MP
  restoreHpPercent, // Відновити % від maxHP
  restoreMpPercent, // Відновити % від maxMP
  // ... інші можливі ефекти в майбутньому
}

class InventoryItem {
  static const String smallHealthPotionId = 'potion_health_small';

  final String itemId;
  final String name;
  final String description;
  final ItemType type;
  final String iconPath;
  final bool isStackable;
  final int quantity;

  final Map<ItemEffectType, double> effects;

  InventoryItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.type,
    required this.iconPath,
    this.isStackable = true,
    required this.quantity,
    this.effects = const {},
  });

  InventoryItem copyWith({int? quantity}) {
    return InventoryItem(
      itemId: itemId,
      name: name,
      description: description,
      type: type,
      iconPath: iconPath,
      isStackable: isStackable,
      quantity: quantity ?? this.quantity,
      effects: effects,
    );
  }

  InventoryItem addQuantity(int amount) =>
      copyWith(quantity: quantity + amount);

  InventoryItem removeQuantity(int amount) {
    final newQuantity = quantity - amount;
    return copyWith(quantity: newQuantity < 0 ? 0 : newQuantity);
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'quantity': quantity,
    };
  }

  factory InventoryItem.fromJson(
      Map<String, dynamic> json, Map<String, InventoryItem> itemDictionary) {
    final itemId = json['itemId'] as String;
    final quantity = json['quantity'] as int;

    final templateItem = itemDictionary[itemId];

    const unknownItemName = 'Невідомий Предмет';
    const unknownItemDescription = 'Опис відсутній';
    const unknownItemIcon = 'assets/icons/items/unknown.svg';

    if (templateItem == null) {
      return InventoryItem(
        itemId: itemId,
        name: unknownItemName,
        description: unknownItemDescription,
        type: ItemType.collectible,
        iconPath: unknownItemIcon,
        quantity: quantity,
      );
    }

    return templateItem.copyWith(quantity: quantity);
  }
}

enum ItemType {
  potion,
  key,
  material,
  equipment,
  collectible,
}

enum ItemEffectType {
  restoreHp,
  restoreMp,
  restoreHpPercent,
  restoreMpPercent,
}

class QuestItemReward {
  final String itemId;
  final int quantity;

  const QuestItemReward({
    required this.itemId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'quantity': quantity,
    };
  }

  factory QuestItemReward.fromJson(Map<String, dynamic> json) {
    return QuestItemReward(
      itemId: json['itemId'] as String? ?? 'unknown',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestItemReward &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          quantity == other.quantity;

  @override
  int get hashCode => itemId.hashCode ^ quantity.hashCode;
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

  const InventoryItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.type,
    required this.iconPath,
    this.isStackable = true,
    required this.quantity,
    this.effects = const {},
  });

  InventoryItem copyWith({
    String? itemId,
    String? name,
    String? description,
    ItemType? type,
    String? iconPath,
    bool? isStackable,
    int? quantity,
    Map<ItemEffectType, double>? effects,
  }) {
    return InventoryItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      iconPath: iconPath ?? this.iconPath,
      isStackable: isStackable ?? this.isStackable,
      quantity: quantity ?? this.quantity,
      effects: effects ?? this.effects,
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

  factory InventoryItem.fromFirestore(Map<String, dynamic> data) {
    final itemId = data['id'] as String? ?? data['itemId'] as String? ?? '';
    final effectsRaw = data['effects'] as Map<String, dynamic>?;
    final Map<ItemEffectType, double> effects = {};

    if (effectsRaw != null) {
      for (final entry in effectsRaw.entries) {
        try {
          final effectType = ItemEffectType.values.byName(entry.key);
          effects[effectType] = (entry.value as num).toDouble();
        } catch (_) {}
      }
    }

    ItemType itemType = ItemType.collectible;
    if (data['type'] != null) {
      try {
        itemType = ItemType.values.byName(data['type'] as String);
      } catch (_) {}
    }

    return InventoryItem(
      itemId: itemId,
      name: data['name'] as String? ?? 'Unknown Item',
      description: data['description'] as String? ?? '',
      type: itemType,
      iconPath: data['iconPath'] as String? ?? 'assets/icons/items/unknown.svg',
      isStackable: data['isStackable'] as bool? ?? true,
      quantity: 1,
      effects: effects,
    );
  }

  factory InventoryItem.fromJson(
      Map<String, dynamic> json, Map<String, InventoryItem> itemDictionary) {
    final itemId = json['itemId'] as String? ?? '';
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;

    final templateItem = itemDictionary[itemId];

    const unknownItemName = 'Unknown Item';
    const unknownItemDescription = 'Unknown Item Description';
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

  String get effectsSummary {
    if (effects.isEmpty) return '';
    final List<String> summaries = [];
    effects.forEach((effect, value) {
      switch (effect) {
        case ItemEffectType.restoreHp:
          summaries.add('Restores ${value.toInt()} HP');
          break;
        case ItemEffectType.restoreMp:
          summaries.add('Restores ${value.toInt()} MP');
          break;
        case ItemEffectType.restoreHpPercent:
          summaries.add('Restores ${value.toInt()}% Max HP');
          break;
        case ItemEffectType.restoreMpPercent:
          summaries.add('Restores ${value.toInt()}% Max MP');
          break;
      }
    });
    return summaries.join(', ');
  }
}

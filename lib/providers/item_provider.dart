import 'package:awakening/services/cloud_logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/inventory_item_model.dart';

class ItemProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CloudLoggerService _logger = CloudLoggerService();

  Map<String, InventoryItem> _itemDictionary = {};
  bool _isLoading = true;

  Map<String, InventoryItem> get itemDictionary => _itemDictionary;
  bool get isLoading => _isLoading;

  List<String> get allItemIds => _itemDictionary.keys.toList();

  ItemProvider() {
    _loadAllItemsFromFirestore();
  }

  Future<void> _loadAllItemsFromFirestore() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('items').get();

      final Map<String, InventoryItem> loadedItems = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final itemId = data['id'] as String;

        final effects = (data['effects'] as Map<String, dynamic>?)?.map(
            (key, value) =>
                MapEntry(ItemEffectType.values.byName(key), value as double));

        final itemTemplate = InventoryItem(
          itemId: itemId,
          name: data['name'] as String,
          description: data['description'] as String,
          type: ItemType.values.byName(data['type'] as String),
          iconPath: data['iconPath'] as String,
          isStackable: data['isStackable'] as bool,
          quantity: 1,
          effects: effects ?? {},
        );
        loadedItems[itemId] = itemTemplate;
      }

      _itemDictionary = loadedItems;
      _logger.writeLog(
        message: "Loaded ${_itemDictionary.length} items from Firestore.",
        payload: {
          "itemCount": _itemDictionary.length,
          "timestamp": DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.writeLog(
        message: "Error loading items from Firestore: $e",
        severity: CloudLogSeverity.error,
        payload: {
          "error": e.toString(),
          "timestamp": DateTime.now().toIso8601String(),
        },
      );
      _itemDictionary = {};
    }

    _isLoading = false;
    notifyListeners();
  }

  InventoryItem? getItemById(String itemId) {
    return _itemDictionary[itemId];
  }
}

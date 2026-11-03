import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../repositories/catalog_repository.dart';
import '../services/app_logger_service.dart';

class ItemProvider with ChangeNotifier {
  final CatalogRepository _catalogRepository;
  final AppLoggerService _logger = AppLoggerService();

  Map<String, InventoryItem> _itemDictionary = {};
  bool _isLoading = true;

  Map<String, InventoryItem> get itemDictionary => _itemDictionary;
  bool get isLoading => _isLoading;
  List<String> get allItemIds => _itemDictionary.keys.toList();

  ItemProvider({CatalogRepository? catalogRepository})
      : _catalogRepository = catalogRepository ?? CatalogRepository() {
    loadAllItems();
  }

  Future<void> loadAllItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      _itemDictionary = await _catalogRepository.fetchItems();
      _logger.writeLog(
        message: "Loaded ${_itemDictionary.length} items from catalog.",
        severity: LogSeverity.info,
      );
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error loading items from catalog: $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
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

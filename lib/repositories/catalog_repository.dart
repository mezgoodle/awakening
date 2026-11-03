import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';
import '../models/skill_model.dart';

class CatalogRepository {
  final FirebaseFirestore _firestore;

  CatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, InventoryItem>> fetchItems() async {
    final snapshot = await _firestore.collection('items').get();
    final Map<String, InventoryItem> items = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final item = InventoryItem.fromFirestore(data);
      items[item.itemId] = item;
    }
    return items;
  }

  Future<List<SkillModel>> fetchSkills() async {
    final snapshot = await _firestore.collection('skills').get();
    return snapshot.docs.map((doc) => SkillModel.fromFirestore(doc.data())).toList();
  }
}

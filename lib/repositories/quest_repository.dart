import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quest_model.dart';

class QuestRepository {
  final FirebaseFirestore _firestore;

  QuestRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _questsCollection(String uid) =>
      _firestore.collection('players').doc(uid).collection('quests');

  Future<List<QuestModel>> fetchActiveQuests(String uid) async {
    final snapshot = await _questsCollection(uid)
        .where('isCompleted', isEqualTo: false)
        .get();
    return snapshot.docs
        .map((doc) => QuestModel.fromJson(doc.data()! as Map<String, dynamic>))
        .toList();
  }

  Future<List<QuestModel>> fetchCompletedQuests(String uid, {int limit = 50}) async {
    final snapshot = await _questsCollection(uid)
        .where('isCompleted', isEqualTo: true)
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => QuestModel.fromJson(doc.data()! as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveQuest(String uid, QuestModel quest) async {
    await _questsCollection(uid).doc(quest.id).set(quest.toJson());
  }

  Future<void> markQuestCompleted(
      String uid, String questId, DateTime completedAt) async {
    await _questsCollection(uid).doc(questId).update({
      'isCompleted': true,
      'completedAt': completedAt.toIso8601String(),
    });
  }

  Future<void> revertQuestCompletion(String uid, String questId) async {
    await _questsCollection(uid).doc(questId).update({
      'isCompleted': false,
      'completedAt': null,
    });
  }

  Future<void> deleteAllQuests(String uid) async {
    final snapshot = await _questsCollection(uid).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

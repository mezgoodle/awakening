import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';

class PlayerRepository {
  final FirebaseFirestore _firestore;

  PlayerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference _playerDoc(String uid) =>
      _firestore.collection('players').doc(uid);

  Future<PlayerModel?> fetchPlayer(String uid) async {
    final doc = await _playerDoc(uid).get();
    if (doc.exists && doc.data() != null) {
      return PlayerModel.fromJson(doc.data()! as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> savePlayer(String uid, PlayerModel player) async {
    await _playerDoc(uid).set(player.toJson());
  }

  Future<void> updateDailyQuestGenerationDate(String uid, String dateStr) async {
    await _playerDoc(uid).update({
      'lastDailyQuestGenerationDate': dateStr,
    });
  }

  Future<void> deletePlayer(String uid) async {
    await _playerDoc(uid).delete();
  }
}

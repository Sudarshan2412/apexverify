import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final String matchId = 'demo_match_001';

  Future<Map<String, dynamic>> getOfficialData() async {
    final doc = await _db
        .collection('matches')
        .doc(matchId)
        .collection('official')
        .doc('current')
        .get();
    return doc.data() ?? {};
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final String matchId = 'demo_match_001';

  /// Fetches the current official match data from Firestore.
  ///
  /// Step 3.2 Member D Step 2: logs homeTeam, awayTeam, score, and clock
  /// on every comparison call so you can confirm it is pulling from the
  /// correct document (matches/{matchId}/official/current).
  Future<Map<String, dynamic>> getOfficialData() async {
    final doc = await _db
        .collection('matches')
        .doc(matchId)
        .collection('official')
        .doc('current')
        .get();

    final data = doc.data() ?? {};

    // Debug logging — Step 3.2 Member D Step 2
    debugPrint('[FirestoreService] Official data from matches/$matchId/official/current:');
    debugPrint('  homeTeam : ${data['homeTeam'] ?? '(not set)'}');
    debugPrint('  awayTeam : ${data['awayTeam'] ?? '(not set)'}');
    debugPrint('  score    : ${data['score'] ?? '(not set)'}');
    debugPrint('  clock    : ${data['clock'] ?? '(not set)'}');

    return data;
  }
}

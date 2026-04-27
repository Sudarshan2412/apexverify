import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_snapshot.dart';
import '../models/violation_alert.dart';
import '../services/comparison_service.dart';
import '../services/firestore_service.dart';
import 'ocr_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phase 3: Real ComparisonService wired in (Step 3.2 + 3.3)
//
// Wiring:
//   snapshotStreamProvider (OCR output from Member C)
//     → ComparisonService.compare(snap)      (Member D Step 1)
//       → ComparisonService.alertStream
//         → alertStreamProvider              (Member A dashboard)
// ─────────────────────────────────────────────────────────────────────────────

/// FirestoreService singleton — reads official match data from Firestore.
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// ComparisonService singleton — compares OCR snapshots against Firestore
/// official data and emits ViolationAlerts (or null for clean frames).
final comparisonServiceProvider = Provider<ComparisonService>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final service = ComparisonService(firestoreService);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Step 3.2 Member D Step 1: Subscribe ComparisonService to snapshotStream.
/// Step 3.3 Member D Step 5: Expose Stream<ViolationAlert?> to Member A's dashboard.
///
/// Every MatchSnapshot emitted by the OCR pipeline is fed into
/// ComparisonService.compare(). The ComparisonService checks score, clock,
/// and overlay against Firestore and emits:
///   - null           → clean frame (no violation)
///   - ViolationAlert → mismatch detected (score, clock, or overlay)
final alertStreamProvider = StreamProvider<ViolationAlert?>((ref) {
  final comparisonService = ref.watch(comparisonServiceProvider);

  // Step 3.2 Member D Step 1:
  // Use ref.listen (Riverpod 2.x recommended, forward-compatible with 3.0)
  // so that every MatchSnapshot emission drives ComparisonService.compare().
  ref.listen<AsyncValue<MatchSnapshot>>(snapshotStreamProvider, (_, next) {
    next.whenData((snap) {
      debugPrint('[AlertProvider] Snapshot received → feeding to ComparisonService');
      debugPrint('  Score: ${snap.score}');
      debugPrint('  Clock: ${snap.clock}');
      debugPrint('  Overlay: ${snap.hasOverlay}');
      comparisonService.compare(snap);
    });
    next.whenOrNull(
      error: (e, _) => debugPrint('[AlertProvider] snapshotStream error: $e'),
    );
  });

  // Step 3.3 Member D Step 5:
  // Stream get alertStream => _alertController.stream  (in ComparisonService)
  // This is the stream Member A's dashboard subscribes to.
  return comparisonService.alertStream;
});

/// Accumulated DMCA log entries — appended on every non-null alert.
/// Member A's DmcaLogPanel reads this provider.
final dmcaLogProvider =
    StateNotifierProvider<DmcaLogNotifier, List<ViolationAlert>>(
  (ref) {
    final notifier = DmcaLogNotifier();
    ref.listen<AsyncValue<ViolationAlert?>>(alertStreamProvider, (_, next) {
      next.whenData((alert) {
        if (alert != null) notifier.append(alert);
      });
    });
    return notifier;
  },
);

class DmcaLogNotifier extends StateNotifier<List<ViolationAlert>> {
  DmcaLogNotifier() : super([]);
  void append(ViolationAlert alert) => state = [...state, alert];
  void clear() => state = [];
}
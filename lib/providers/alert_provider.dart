import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/violation_alert.dart';

// ─── HANDOFF (Member D → Member A) ───────────────────────────────────────────
// When Member D commits comparison_service.dart, uncomment the import below
// and replace the stubAlertStream with the real one.
//
// import '../services/comparison_service.dart';
// ─────────────────────────────────────────────────────────────────────────────

// ── Stub (remove once Member D's ComparisonService lands) ────────────────────
Stream<ViolationAlert?> _stubAlertStream() async* {
  // Emits null (clean) indefinitely until wired to real service.
  // During integration testing, Member D can call ref.read(alertStreamProvider)
  // and push test violations through ComparisonService directly.
  while (true) {
    await Future.delayed(const Duration(seconds: 5));
    yield null; // null = clean frame
  }
}
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes the alert stream. Replace _stubAlertStream() with
/// ComparisonService.alertStream at Phase 3 Step 3.3.
final alertStreamProvider = StreamProvider<ViolationAlert?>((ref) {
  // HANDOFF: replace with ref.read(comparisonServiceProvider).alertStream
  return _stubAlertStream();
});

/// Accumulated DMCA log entries — appended on every non-null alert.
final dmcaLogProvider = StateNotifierProvider<DmcaLogNotifier, List<ViolationAlert>>(
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_snapshot.dart';
import '../services/ocr_service.dart';
import 'frame_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phase 3 OCR Provider
//
// Wiring (Step 3.1 — Member C):
//   rawFrameStreamProvider  (shared broadcast from FrameSampler)
//     → OcrService.startLivePipeline(frameStream)
//       → OcrService.snapshotStream  →  snapshotStreamProvider
//
// Downstream (Step 3.2 — Member D):
//   snapshotStreamProvider → ComparisonService.compare(snap) → alertStream
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton OcrService.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService(enableDebugLogs: true);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Step 3.1: Starts the live OCR pipeline by feeding the shared frame
/// broadcast stream into OcrService. Emits a [MatchSnapshot] per frame.
///
/// Uses [rawFrameStreamProvider] so the sampler's startSampling() is called
/// exactly once — shared with the UI frame-preview widget.
final snapshotStreamProvider = StreamProvider<MatchSnapshot>((ref) {
  final url = ref.watch(streamUrlProvider);
  if (url.isEmpty) return const Stream.empty();

  final ocrService = ref.watch(ocrServiceProvider);

  // Use the shared broadcast stream from the sampler (not a second call to
  // startSampling, which would close the first subscription).
  final frameStream = ref.watch(rawFrameStreamProvider);

  // Step 3.1 Member C Step 2: Replace static file with live stream.
  // ocrService internally subscribes to frameStream, processes each frame
  // via ML Kit (+Cloud Vision escalation), and adds to snapshotStream.
  ocrService.startLivePipeline(frameStream);

  ref.onDispose(() => ocrService.stopLivePipeline());

  // Step 3.1 Member C Step 5: snapshotStream is exposed and broadcasting.
  return ocrService.snapshotStream;
});

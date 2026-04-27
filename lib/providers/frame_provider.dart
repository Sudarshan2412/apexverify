import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── HANDOFF (Member B → Member A) ───────────────────────────────────────────
// When Member B commits frame_sampler.dart and mock_frame_sampler.dart,
// uncomment the real imports below and delete the stub section.
//
// import '../services/frame_sampler.dart';
// import '../services/mock_frame_sampler.dart';
// ─────────────────────────────────────────────────────────────────────────────

// ── Stub (remove once Member B's files land) ─────────────────────────────────
abstract class FrameSamplerBase {
  Stream<Uint8List> startSampling(String url);
  Future<void> saveCurrentFrame(String filename);
}

class MockFrameSampler implements FrameSamplerBase {
  @override
  Stream<Uint8List> startSampling(String url) async* {
    // emits a 1×1 grey PNG placeholder every 5 seconds
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      // Valid minimal 1x1 PNG (grey pixel). Replace with actual frames from Member B's implementation
      yield Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
        0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0xFE,
        0xFF, 0x80, 0x80, 0x80, 0x30, 0x80, 0xA6, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
    }
  }

  @override
  Future<void> saveCurrentFrame(String filename) async {
    // no-op in mock; real implementation writes PNG to disk
  }
}
// ─────────────────────────────────────────────────────────────────────────────

/// Toggle this constant to switch between mock and real sampler.
/// Phase 2: useMock = true
/// Phase 3 Step 3.3: set useMock = false
const bool useMock = true; // ← CHANGE THIS at Phase 3 Step 3.3

final frameSamplerProvider = Provider<FrameSamplerBase>((ref) {
  if (useMock) return MockFrameSampler();
  // HANDOFF: return real FrameSampler() once Member B's file exists
  return MockFrameSampler();
});

final streamUrlProvider = StateProvider<String>((ref) => '');

final frameStreamProvider = StreamProvider<Uint8List>((ref) {
  final url = ref.watch(streamUrlProvider);
  if (url.isEmpty) return const Stream.empty();
  final sampler = ref.watch(frameSamplerProvider);
  return sampler.startSampling(url);
});

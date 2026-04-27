import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/frame_sampler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phase 3: Real FrameSampler is now wired in.
// Toggle useMock to switch between RealMockFrameSampler (offline/static images)
// and FrameSampler (live stream via yt-dlp + ffmpeg).
// ─────────────────────────────────────────────────────────────────────────────

/// Toggle this constant to switch between mock and real sampler.
/// Phase 2: useMock = true  (static images, no ffmpeg/yt-dlp needed)
/// Phase 3: useMock = false (live stream from YouTube/Twitch)
const bool useMock = false; // ← Phase 3: live pipeline active

final frameSamplerProvider = Provider<BaseFrameSampler>((ref) {
  if (useMock) return RealMockFrameSampler();
  return FrameSampler();
});

final streamUrlProvider = StateProvider<String>((ref) => '');

/// Raw broadcast stream from the sampler. Created once per URL change.
/// Both the frame display (UI) and the OCR pipeline share this single
/// `Stream<Uint8List>` to avoid calling startSampling() twice.
final rawFrameStreamProvider = Provider<Stream<Uint8List>>((ref) {
  final url = ref.watch(streamUrlProvider);
  if (url.isEmpty) return const Stream<Uint8List>.empty();
  final sampler = ref.watch(frameSamplerProvider);
  return sampler.startSampling(url);
});

/// StreamProvider for the UI frame display.
/// Wraps the raw stream so Riverpod widgets can use AsyncValue<Uint8List>.
final frameStreamProvider = StreamProvider<Uint8List>((ref) {
  return ref.watch(rawFrameStreamProvider);
});

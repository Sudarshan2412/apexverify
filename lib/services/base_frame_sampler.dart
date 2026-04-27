import 'dart:typed_data';

/// Platform-agnostic interface for anything that can produce frames.
///
/// IMPORTANT: This file must stay web-safe (no `dart:io`).
abstract class BaseFrameSampler {
  /// Returns a stream of preprocessed PNG frames (grayscale + contrast).
  Stream<Uint8List> startSampling(String url);

  /// Saves the last emitted frame.
  ///
  /// On Web, implementations may no-op.
  Future<void> saveCurrentFrame(String outputPath);

  void dispose();
}

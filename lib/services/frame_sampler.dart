import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────────────────────
// ABSTRACT INTERFACE
// Both RealMockFrameSampler and FrameSampler implement this.
// Member A will depend on this interface in Phase 3.1 when
// swapping the mock for the real implementation.
// ─────────────────────────────────────────────────────────────
abstract class BaseFrameSampler {
  /// Returns a stream of preprocessed PNG frames (grayscale + contrast).
  Stream<Uint8List> startSampling(String url);

  /// Saves the last emitted frame to disk. Member A calls this
  /// when the screenshot button is pressed.
  Future<void> saveCurrentFrame(String outputPath);

  void dispose();
}

// ─────────────────────────────────────────────────────────────
// REAL MOCK — loads actual scoreboard PNGs from assets,
// cycles through them every 5 seconds, applies preprocessing.
//
// Used by Member C for offline OCR testing on static images.
// Member A does NOT use this — they have their own MockFrameSampler.
// ─────────────────────────────────────────────────────────────
class RealMockFrameSampler implements BaseFrameSampler {
  final Duration _interval;
  Timer? _timer;
  StreamController<Uint8List>? _controller;
  Uint8List? _lastFrame;
  int _frameIndex = 0;

  final List<String> _testAssets = [
    'assets/test_scoreboards/nba_01.png',
    'assets/test_scoreboards/epl_01.png',
    'assets/test_scoreboards/epl_02.png',
    'assets/test_scoreboards/ucl_01.png',
  ];

  RealMockFrameSampler({
    Duration interval = const Duration(seconds: 5),
  }) : _interval = interval;

  @override
  Stream<Uint8List> startSampling(String url) {
    _controller?.close();
    _controller = StreamController<Uint8List>.broadcast();

    // Emit first frame immediately so there's no blank delay.
    _emitNext();

    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _emitNext());

    return _controller!.stream;
  }

  Future<void> _emitNext() async {
    try {
      final assetPath = _testAssets[_frameIndex % _testAssets.length];
      _frameIndex++;

      final byteData = await rootBundle.load(assetPath);
      final raw = byteData.buffer.asUint8List();
      final processed = _preprocess(raw);

      _lastFrame = processed;
      _controller?.add(processed);

      print('[RealMockFrameSampler] Emitted: $assetPath (${processed.length} bytes)');
    } catch (e) {
      print('[RealMockFrameSampler] Error emitting frame: $e');
    }
  }

  /// Grayscale + contrast boost at 1.5.
  /// Matches exactly what FrameSampler does on live frames so Member C's
  /// OCR results on static images reflect real pipeline behaviour.
  Uint8List _preprocess(Uint8List rawPngBytes) {
    final image = img.decodeImage(rawPngBytes);
    if (image == null) {
      print('[RealMockFrameSampler] Warning: could not decode image, returning raw bytes.');
      return rawPngBytes;
    }
    final grayscale = img.grayscale(image);
    final contrasted = img.adjustColor(grayscale, contrast: 1.5);
    return Uint8List.fromList(img.encodePng(contrasted));
  }

  @override
  Future<void> saveCurrentFrame(String outputPath) async {
    if (_lastFrame == null) {
      print('[RealMockFrameSampler] No frame available to save yet.');
      return;
    }
    final file = File(outputPath);
    await file.writeAsBytes(_lastFrame!);
    print('[RealMockFrameSampler] Saved to $outputPath (${_lastFrame!.length} bytes)');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.close();
  }
}

// ─────────────────────────────────────────────────────────────
// REAL FRAME SAMPLER — Phase 3.1 onwards
// Uses ffmpeg to grab one frame every 5 seconds from a live
// stream URL (YouTube / Twitch). Applies same preprocessing.
//
// Requires ffmpeg installed on the host machine:
//   Windows: winget install ffmpeg
//
// Member A swaps RealMockFrameSampler for this in Phase 3.1.
// The interface is identical — it is a one-line change.
// ─────────────────────────────────────────────────────────────
class FrameSampler implements BaseFrameSampler {
  final Duration _interval;
  Timer? _timer;
  StreamController<Uint8List>? _controller;
  Uint8List? _lastFrame;

  FrameSampler({
    Duration interval = const Duration(seconds: 5),
  }) : _interval = interval;

  @override
  Stream<Uint8List> startSampling(String url) {
    _controller?.close();
    _controller = StreamController<Uint8List>.broadcast();

    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) async {
      try {
        final raw = await _grabFrame(url);
        if (raw != null) {
          final processed = _preprocess(raw);
          _lastFrame = processed;
          _controller?.add(processed);
        }
      } catch (e) {
        print('[FrameSampler] Error: $e');
      }
    });

    return _controller!.stream;
  }

  /// Calls ffmpeg as a subprocess to extract a single PNG frame
  /// from the stream URL and return it as raw bytes.
  Future<Uint8List?> _grabFrame(String url) async {
    final result = await Process.run(
      'ffmpeg',
      [
        '-y',
        '-i', url,
        '-vframes', '1',
        '-f', 'image2pipe',
        '-vcodec', 'png',
        'pipe:1',
      ],
      stdoutEncoding: null, // must be null to get raw bytes, not a String
    );

    if (result.exitCode != 0) {
      print('[FrameSampler] ffmpeg error (exit ${result.exitCode}): ${result.stderr}');
      return null;
    }

    final bytes = result.stdout;
    if (bytes is List<int>) {
      return Uint8List.fromList(bytes);
    }
    return null;
  }

  Uint8List _preprocess(Uint8List rawPngBytes) {
    final image = img.decodeImage(rawPngBytes);
    if (image == null) return rawPngBytes;
    final grayscale = img.grayscale(image);
    final contrasted = img.adjustColor(grayscale, contrast: 1.5);
    return Uint8List.fromList(img.encodePng(contrasted));
  }

  @override
  Future<void> saveCurrentFrame(String outputPath) async {
    if (_lastFrame == null) {
      print('[FrameSampler] No frame available to save yet.');
      return;
    }
    final file = File(outputPath);
    await file.writeAsBytes(_lastFrame!);
    print('[FrameSampler] Saved to $outputPath');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.close();
  }
}

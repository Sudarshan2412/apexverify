// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:image/image.dart' as img;

// // ─────────────────────────────────────────────────────────────
// // ABSTRACT INTERFACE
// // Both RealMockFrameSampler and FrameSampler implement this.
// // Member A will depend on this interface in Phase 3.1 when
// // swapping the mock for the real implementation.
// // ─────────────────────────────────────────────────────────────
// abstract class BaseFrameSampler {
//   /// Returns a stream of preprocessed PNG frames (grayscale + contrast).
//   Stream<Uint8List> startSampling(String url);

//   /// Saves the last emitted frame to disk. Member A calls this
//   /// when the screenshot button is pressed.
//   Future<void> saveCurrentFrame(String outputPath);

//   void dispose();
// }

// // ─────────────────────────────────────────────────────────────
// // REAL MOCK — loads actual scoreboard PNGs from assets,
// // cycles through them every 5 seconds, applies preprocessing.
// //
// // Used by Member C for offline OCR testing on static images.
// // Member A does NOT use this — they have their own MockFrameSampler.
// // ─────────────────────────────────────────────────────────────
// class RealMockFrameSampler implements BaseFrameSampler {
//   final Duration _interval;
//   Timer? _timer;
//   StreamController<Uint8List>? _controller;
//   Uint8List? _lastFrame;
//   int _frameIndex = 0;

//   final List<String> _testAssets = [
//     'assets/test_scoreboards/nba_01.png',
//     'assets/test_scoreboards/epl_01.png',
//     'assets/test_scoreboards/epl_02.png',
//     'assets/test_scoreboards/ucl_01.png',
//   ];

//   RealMockFrameSampler({
//     Duration interval = const Duration(seconds: 5),
//   }) : _interval = interval;

//   @override
//   Stream<Uint8List> startSampling(String url) {
//     _controller?.close();
//     _controller = StreamController<Uint8List>.broadcast();

//     // Emit first frame immediately so there's no blank delay.
//     _emitNext();

//     _timer?.cancel();
//     _timer = Timer.periodic(_interval, (_) => _emitNext());

//     return _controller!.stream;
//   }

//   Future<void> _emitNext() async {
//     try {
//       final assetPath = _testAssets[_frameIndex % _testAssets.length];
//       _frameIndex++;

//       final byteData = await rootBundle.load(assetPath);
//       final raw = byteData.buffer.asUint8List();
//       final processed = _preprocess(raw);

//       _lastFrame = processed;
//       _controller?.add(processed);

//       print('[RealMockFrameSampler] Emitted: $assetPath (${processed.length} bytes)');
//     } catch (e) {
//       print('[RealMockFrameSampler] Error emitting frame: $e');
//     }
//   }

//   /// Grayscale + contrast boost at 1.5.
//   /// Matches exactly what FrameSampler does on live frames so Member C's
//   /// OCR results on static images reflect real pipeline behaviour.
//   Uint8List _preprocess(Uint8List rawPngBytes) {
//     final image = img.decodeImage(rawPngBytes);
//     if (image == null) {
//       print('[RealMockFrameSampler] Warning: could not decode image, returning raw bytes.');
//       return rawPngBytes;
//     }
//     final grayscale = img.grayscale(image);
//     final contrasted = img.adjustColor(grayscale, contrast: 1.5);
//     return Uint8List.fromList(img.encodePng(contrasted));
//   }

//   @override
//   Future<void> saveCurrentFrame(String outputPath) async {
//     if (_lastFrame == null) {
//       print('[RealMockFrameSampler] No frame available to save yet.');
//       return;
//     }
//     final file = File(outputPath);
//     await file.writeAsBytes(_lastFrame!);
//     print('[RealMockFrameSampler] Saved to $outputPath (${_lastFrame!.length} bytes)');
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _controller?.close();
//   }
// }

// // ─────────────────────────────────────────────────────────────
// // REAL FRAME SAMPLER — Phase 3.1 onwards
// // Uses ffmpeg to grab one frame every 5 seconds from a live
// // stream URL (YouTube / Twitch). Applies same preprocessing.
// //
// // Requires ffmpeg installed on the host machine:
// //   Windows: winget install ffmpeg
// //
// // Member A swaps RealMockFrameSampler for this in Phase 3.1.
// // The interface is identical — it is a one-line change.
// // ─────────────────────────────────────────────────────────────
// class FrameSampler implements BaseFrameSampler {
//   final Duration _interval;
//   Timer? _timer;
//   StreamController<Uint8List>? _controller;
//   Uint8List? _lastFrame;

//   FrameSampler({
//     Duration interval = const Duration(seconds: 5),
//   }) : _interval = interval;

//   @override
//   Stream<Uint8List> startSampling(String url) {
//     _controller?.close();
//     _controller = StreamController<Uint8List>.broadcast();

//     _timer?.cancel();
//     _timer = Timer.periodic(_interval, (_) async {
//       try {
//         final raw = await _grabFrame(url);
//         if (raw != null) {
//           final processed = _preprocess(raw);
//           _lastFrame = processed;
//           _controller?.add(processed);
//         }
//       } catch (e) {
//         print('[FrameSampler] Error: $e');
//       }
//     });

//     return _controller!.stream;
//   }

//   /// Calls ffmpeg as a subprocess to extract a single PNG frame
//   /// from the stream URL and return it as raw bytes.
//   Future<Uint8List?> _grabFrame(String url) async {
//     final result = await Process.run(
//       'ffmpeg',
//       [
//         '-y',
//         '-i', url,
//         '-vframes', '1',
//         '-f', 'image2pipe',
//         '-vcodec', 'png',
//         'pipe:1',
//       ],
//       stdoutEncoding: null, // must be null to get raw bytes, not a String
//     );

//     if (result.exitCode != 0) {
//       print('[FrameSampler] ffmpeg error (exit ${result.exitCode}): ${result.stderr}');
//       return null;
//     }

//     final bytes = result.stdout;
//     if (bytes is List<int>) {
//       return Uint8List.fromList(bytes);
//     }
//     return null;
//   }

//   Uint8List _preprocess(Uint8List rawPngBytes) {
//     final image = img.decodeImage(rawPngBytes);
//     if (image == null) return rawPngBytes;
//     final grayscale = img.grayscale(image);
//     final contrasted = img.adjustColor(grayscale, contrast: 1.5);
//     return Uint8List.fromList(img.encodePng(contrasted));
//   }

//   @override
//   Future<void> saveCurrentFrame(String outputPath) async {
//     if (_lastFrame == null) {
//       print('[FrameSampler] No frame available to save yet.');
//       return;
//     }
//     final file = File(outputPath);
//     await file.writeAsBytes(_lastFrame!);
//     print('[FrameSampler] Saved to $outputPath');
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _controller?.close();
//   }
// }
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────────────────────
// ABSTRACT INTERFACE
// Both RealMockFrameSampler and FrameSampler implement this.
// Member A depends on this interface — swapping mock for real
// is a one-line change in the provider.
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
//
// Supports YouTube, Twitch, and any direct stream URL.
// Uses yt-dlp to resolve YouTube/Twitch page URLs into real
// stream URLs ONCE, then caches the result. ffmpeg grabs one
// PNG frame per interval from the resolved stream URL.
//
// Requirements (install on Windows before running):
//   winget install yt-dlp
//   winget install ffmpeg
//
// Member A swaps RealMockFrameSampler for this in Phase 3.3.
// The interface is identical — it is a one-line change.
// ─────────────────────────────────────────────────────────────
class FrameSampler implements BaseFrameSampler {
  final Duration _interval;
  Timer? _timer;
  StreamController<Uint8List>? _controller;
  Uint8List? _lastFrame;

  /// Cached resolved stream URL. yt-dlp is called only once per
  /// startSampling() call — not on every 5-second tick.
  String? _resolvedStreamUrl;

  FrameSampler({
    Duration interval = const Duration(seconds: 5),
  }) : _interval = interval;

  @override
  Stream<Uint8List> startSampling(String url) {
    // Reset state for a fresh session.
    _controller?.close();
    _controller = StreamController<Uint8List>.broadcast();
    _resolvedStreamUrl = null; // clear cache so new URL resolves fresh

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
        print('[FrameSampler] Tick error: $e');
      }
    });

    return _controller!.stream;
  }

  // ─────────────────────────────────────────────────────────
  // _resolveStreamUrl
  // Calls yt-dlp once to get the real stream URL from a
  // YouTube or Twitch page URL. Returns null on failure.
  // Direct stream URLs (e.g. .m3u8) skip yt-dlp entirely.
  // ─────────────────────────────────────────────────────────
  Future<String?> _resolveStreamUrl(String url) async {
    // If it already looks like a direct stream, skip yt-dlp.
    final isDirectStream = url.contains('.m3u8') ||
        url.contains('.ts') ||
        url.contains('manifest');

    if (isDirectStream) {
      print('[FrameSampler] Direct stream URL detected, skipping yt-dlp.');
      return url;
    }

    print('[FrameSampler] Resolving stream URL via yt-dlp...');

    final result = await Process.run(
      'yt-dlp',
      [
        '-g',                   // print the direct stream URL only
        '--no-playlist',        // never download a whole playlist
        '-f', 'best[ext=mp4]',  // prefer mp4; falls back automatically
        url,
      ],
    );

    if (result.exitCode != 0) {
      print('[FrameSampler] yt-dlp failed (exit ${result.exitCode}): ${result.stderr}');
      return null;
    }

    final resolved = (result.stdout as String).trim();
    if (resolved.isEmpty) {
      print('[FrameSampler] yt-dlp returned an empty URL.');
      return null;
    }

    print('[FrameSampler] Resolved: ${resolved.substring(0, resolved.length.clamp(0, 80))}...');
    return resolved;
  }

  // ─────────────────────────────────────────────────────────
  // _grabFrame
  // Resolves the stream URL on the first call (cached after).
  // Then calls ffmpeg to extract one PNG frame via pipe.
  // Returns null on any failure — the timer loop skips silently.
  // ─────────────────────────────────────────────────────────
  Future<Uint8List?> _grabFrame(String url) async {
    // Resolve once, reuse on every subsequent tick.
    _resolvedStreamUrl ??= await _resolveStreamUrl(url);

    if (_resolvedStreamUrl == null) {
      print('[FrameSampler] No resolved stream URL — skipping frame grab.');
      return null;
    }

    final result = await Process.run(
      'ffmpeg',
      [
        '-y',                   // overwrite output without prompting
        '-i', _resolvedStreamUrl!,
        '-vframes', '1',        // grab exactly one frame
        '-f', 'image2pipe',     // output format: pipe
        '-vcodec', 'png',       // encode as PNG
        'pipe:1',               // pipe stdout
      ],
      stdoutEncoding: null,     // MUST be null to receive raw bytes
    );

    if (result.exitCode != 0) {
      print('[FrameSampler] ffmpeg error (exit ${result.exitCode}): ${result.stderr}');

      // If ffmpeg fails, the cached URL may have expired (YouTube URLs
      // are time-limited). Clear the cache so yt-dlp re-resolves next tick.
      print('[FrameSampler] Clearing cached URL — will re-resolve on next tick.');
      _resolvedStreamUrl = null;

      return null;
    }

    final bytes = result.stdout;
    if (bytes is List<int> && bytes.isNotEmpty) {
      print('[FrameSampler] Frame grabbed (${bytes.length} bytes).');
      return Uint8List.fromList(bytes);
    }

    print('[FrameSampler] ffmpeg returned empty output.');
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // _preprocess
  // Grayscale + contrast boost at 1.5.
  // Matches RealMockFrameSampler exactly so Member C's OCR
  // accuracy on static images reflects real pipeline behaviour.
  // ─────────────────────────────────────────────────────────
  Uint8List _preprocess(Uint8List rawPngBytes) {
    final image = img.decodeImage(rawPngBytes);
    if (image == null) {
      print('[FrameSampler] Warning: could not decode image, returning raw bytes.');
      return rawPngBytes;
    }
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
    print('[FrameSampler] Saved to $outputPath (${_lastFrame!.length} bytes)');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.close();
    _resolvedStreamUrl = null;
  }
}
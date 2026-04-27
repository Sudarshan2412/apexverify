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

import 'base_frame_sampler.dart';

// ─────────────────────────────────────────────────────────────
// ABSTRACT INTERFACE
// Both RealMockFrameSampler and FrameSampler implement this.
// Member A depends on this interface — swapping mock for real
// is a one-line change in the provider.
// ─────────────────────────────────────────────────────────────
// BaseFrameSampler moved to `base_frame_sampler.dart` (web-safe).

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

  bool _grabInFlight = false;
  static const Duration _processTimeout = Duration(seconds: 12);

  /// Cached resolved stream URL. yt-dlp is called only once per
  /// startSampling() call — not on every 5-second tick.
  String? _resolvedStreamUrl;

  /// For non-HLS sources (VOD/direct MP4), repeated ffmpeg invocations will
  /// otherwise decode timestamp 0 every time. We advance a simple seek offset
  /// so each tick grabs a later moment in the video.
  int _vodSeekSeconds = 0;

  FrameSampler({
    Duration interval = const Duration(seconds: 5),
  }) : _interval = interval;

  @override
  Stream<Uint8List> startSampling(String url) {
    // Reset state for a fresh session.
    _controller?.close();
    _controller = StreamController<Uint8List>.broadcast();
    _resolvedStreamUrl = null; // clear cache so new URL resolves fresh
    _vodSeekSeconds = 0;

    Future<void> tick() async {
      if (_grabInFlight) return;
      _grabInFlight = true;
      try {
        final raw = await _grabFrame(url, vodSeekSeconds: _vodSeekSeconds);
        // Advance seek for next tick (non-HLS only; ignored for HLS).
        _vodSeekSeconds += _interval.inSeconds;
        if (raw != null) {
          final processed = _preprocess(raw);
          _lastFrame = processed;
          _controller?.add(processed);
        }
      } catch (e) {
        print('[FrameSampler] Tick error: $e');
      } finally {
        _grabInFlight = false;
      }
    }

    // Emit the first frame immediately so the UI doesn't look stuck.
    // (Keeps the same behaviour as RealMockFrameSampler.)
    unawaited(tick());

    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => tick());

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

    print('[FrameSampler] Resolving stream URL via yt-*...');

    // Prefer `yt-plb` if installed (requested by user). Fall back to `yt-dlp`.
    final candidates = <String>['yt-plb', 'yt-dlp'];
    ProcessResult? result;
    for (final exe in candidates) {
      result = await _runProcessWithTimeout(
        exe,
        [
          '-g', // print the direct stream URL only
          '--no-playlist',
          '-f', 'best[ext=mp4]',
          url,
        ],
        timeout: _processTimeout,
      );
      if (result.exitCode == 0) {
        break;
      }
    }

    if (result == null || result.exitCode != 0) {
      print('[FrameSampler] yt-* failed (exit ${result?.exitCode}): ${result?.stderr}');
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
  Future<Uint8List?> _grabFrame(String url, {required int vodSeekSeconds}) async {
    // Resolve once, reuse on every subsequent tick.
    _resolvedStreamUrl ??= await _resolveStreamUrl(url);

    if (_resolvedStreamUrl == null) {
      print('[FrameSampler] No resolved stream URL — skipping frame grab.');
      return null;
    }

    final resolved = _resolvedStreamUrl!;
    final isHls = resolved.contains('.m3u8') || resolved.contains('manifest');
    final canSeek = vodSeekSeconds > 0;

    List<String> buildArgs({required bool withSeek}) {
      return <String>[
        'ffmpeg',
        '-y',
        '-nostdin',
        '-hide_banner',
        '-loglevel', 'error',
        // Network reads can block forever on bad connections; this bounds it.
        '-rw_timeout', '15000000', // 15s (microseconds)
        // For HLS live playlists, start from the live edge so repeated 1-frame
        // grabs don't keep returning the same early segment.
        if (isHls) ...['-live_start_index', '-1'],
        // Seek forward so we don't keep grabbing t=0.
        // This also helps for HLS VOD playlists; if unsupported, we retry once
        // without seeking.
        if (withSeek) ...['-ss', vodSeekSeconds.toString()],
        '-i',
        resolved,
        '-vframes', '1',
        '-f', 'image2pipe',
        '-vcodec', 'png',
        'pipe:1',
      ];
    }

    final args = buildArgs(withSeek: canSeek);

    var result = await _runProcessWithTimeout(
      args.first,
      args.sublist(1),
      stdoutAsBytes: true,
      timeout: _processTimeout,
    );

    // If seeking fails on a particular URL type, retry once without seek.
    if (result.exitCode != 0 && canSeek) {
      final fallbackArgs = buildArgs(withSeek: false);
      result = await _runProcessWithTimeout(
        fallbackArgs.first,
        fallbackArgs.sublist(1),
        stdoutAsBytes: true,
        timeout: _processTimeout,
      );
    }

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
    _grabInFlight = false;
  }

  Future<ProcessResult> _runProcessWithTimeout(
    String executable,
    List<String> args, {
    required Duration timeout,
    bool stdoutAsBytes = false,
  }) async {
    try {
      final process = await Process.start(
        executable,
        args,
        // NOTE: `runInShell: true` helps resolve PATH on Windows, but it can
        // leave child processes (ffmpeg) running after a timeout.
        runInShell: true,
      );

      final stdoutBytes = <int>[];
      final stdoutText = StringBuffer();
      final stderrText = StringBuffer();

      StreamSubscription<List<int>>? outSub;
      StreamSubscription<List<int>>? errSub;
      bool finished = false;
      final completer = Completer<ProcessResult>();

      Future<void> finish(int exitCode) async {
        if (finished) return;
        finished = true;
        await outSub?.cancel();
        await errSub?.cancel();
        completer.complete(
          ProcessResult(
            process.pid,
            exitCode,
            stdoutAsBytes ? stdoutBytes : stdoutText.toString(),
            stderrText.toString(),
          ),
        );
      }

      outSub = process.stdout.listen((chunk) {
        if (stdoutAsBytes) {
          stdoutBytes.addAll(chunk);
        } else {
          stdoutText.write(systemEncoding.decode(chunk));
        }
      });

      errSub = process.stderr.listen((chunk) {
        stderrText.write(systemEncoding.decode(chunk));
      });

      final timer = Timer(timeout, () async {
        // Force kill on timeout. On Windows, kill the full process tree.
        try {
          if (Platform.isWindows) {
            await Process.run(
              'taskkill',
              ['/PID', '${process.pid}', '/T', '/F'],
              runInShell: true,
            );
          } else {
            process.kill(ProcessSignal.sigkill);
          }
        } catch (_) {
          try {
            process.kill();
          } catch (_) {
            // ignore
          }
        } finally {
          // IMPORTANT: Don't wait forever for stdout/stderr to close.
          unawaited(finish(-1));
        }
      });

      process.exitCode.then((code) async {
        timer.cancel();
        await finish(code);
      }).catchError((_) async {
        timer.cancel();
        await finish(-1);
      });

      return completer.future;
    } catch (e) {
      // If the executable is missing or fails to start, mimic a ProcessResult.
      return ProcessResult(0, -1, stdoutAsBytes ? <int>[] : '', e.toString());
    }
  }
}
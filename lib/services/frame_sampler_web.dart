import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'base_frame_sampler.dart';

/// Web-safe frame sampler.
///
/// On Web we cannot run `yt-*` or `ffmpeg` locally, so we fetch frames from a
/// backend service that runs those tools and returns a PNG.
class WebFrameSampler implements BaseFrameSampler {
  WebFrameSampler({Duration interval = const Duration(seconds: 5)})
      : _interval = interval;

  final Duration _interval;
  Timer? _timer;
  StreamController<Uint8List>? _controller;
  Uint8List? _lastFrame;
  bool _inFlight = false;
  int _vodSeekSeconds = 0;
  DateTime? _backoffUntil;

  static const String _frameServerUrlEnv = String.fromEnvironment(
    'FRAME_SERVER_URL',
    defaultValue: '',
  );

  @override
  Stream<Uint8List> startSampling(String url) {
    _controller?.close();
    _controller = StreamController<Uint8List>.broadcast();
    _vodSeekSeconds = 0;

    Future<void> tick() async {
      if (_backoffUntil != null && DateTime.now().isBefore(_backoffUntil!)) {
        return;
      }
      if (_inFlight) return;
      _inFlight = true;
      try {
        final bytes = await _fetchFrame(url, vodSeekSeconds: _vodSeekSeconds);
        _vodSeekSeconds += _interval.inSeconds;
        if (bytes == null) return;
        final processed = _preprocess(bytes);
        _lastFrame = processed;
        _controller?.add(processed);
      } catch (e) {
        debugPrint('[WebFrameSampler] Tick error: $e');
      } finally {
        _inFlight = false;
      }
    }

    unawaited(tick());
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => tick());

    return _controller!.stream;
  }

  Future<Uint8List?> _fetchFrame(String url, {required int vodSeekSeconds}) async {
    // Do not default to localhost. If a base URL isn't provided via
    // `--dart-define=FRAME_SERVER_URL=...`, use same-origin `/api/*`.
    final base = _frameServerUrlEnv;

    final uri = base.isEmpty
        ? Uri(path: '/api/frame', queryParameters: {
            'url': url,
            // Used by backend for VOD/direct sources so polling doesn't return
            // the exact same first frame forever.
            't': vodSeekSeconds.toString(),
          })
        : Uri.parse('$base/api/frame').replace(queryParameters: {
            'url': url,
            't': vodSeekSeconds.toString(),
          });

    final resp = await http.get(uri).timeout(const Duration(seconds: 45));
    if (resp.statusCode == 429) {
      // Back off to avoid hammering the backend/YouTube and wasting free-tier minutes.
      _backoffUntil = DateTime.now().add(const Duration(minutes: 10));
      final body = (resp.bodyBytes.isNotEmpty ? resp.body : '').trim();
      debugPrint('[WebFrameSampler] Rate-limited (429). Backing off 10 minutes. ${body.isEmpty ? '' : body}');
      return null;
    }
    if (resp.statusCode != 200) {
      debugPrint('[WebFrameSampler] Server error ${resp.statusCode}: ${resp.body}');
      return null;
    }
    if (resp.bodyBytes.isEmpty) {
      debugPrint('[WebFrameSampler] Empty frame payload');
      return null;
    }
    return resp.bodyBytes;
  }

  Uint8List _preprocess(Uint8List rawPngBytes) {
    final image = img.decodeImage(rawPngBytes);
    if (image == null) {
      debugPrint('[WebFrameSampler] Warning: could not decode image, returning raw bytes.');
      return rawPngBytes;
    }
    final grayscale = img.grayscale(image);
    final contrasted = img.adjustColor(grayscale, contrast: 1.5);
    return Uint8List.fromList(img.encodePng(contrasted));
  }

  @override
  Future<void> saveCurrentFrame(String outputPath) async {
    // Web has no direct filesystem path API; keep this a no-op.
    if (_lastFrame == null) {
      debugPrint('[WebFrameSampler] No frame available to save yet.');
      return;
    }
    debugPrint('[WebFrameSampler] saveCurrentFrame() is not supported on web.');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.close();
    _inFlight = false;
  }
}

/// Web-compatible mock sampler (cycles static assets).
class RealMockFrameSamplerWeb implements BaseFrameSampler {
  RealMockFrameSamplerWeb({Duration interval = const Duration(seconds: 5)})
      : _interval = interval;

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

  @override
  Stream<Uint8List> startSampling(String url) {
    _controller?.close();
    _controller = StreamController<Uint8List>.broadcast();

    Future<void> emitNext() async {
      try {
        final assetPath = _testAssets[_frameIndex % _testAssets.length];
        _frameIndex++;

        final byteData = await rootBundle.load(assetPath);
        final raw = byteData.buffer.asUint8List();
        final processed = _preprocess(raw);

        _lastFrame = processed;
        _controller?.add(processed);
      } catch (e) {
        debugPrint('[RealMockFrameSamplerWeb] Error emitting frame: $e');
      }
    }

    unawaited(emitNext());
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => emitNext());

    return _controller!.stream;
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
      debugPrint('[RealMockFrameSamplerWeb] No frame available to save yet.');
      return;
    }
    debugPrint('[RealMockFrameSamplerWeb] saveCurrentFrame() is not supported on web.');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.close();
  }
}

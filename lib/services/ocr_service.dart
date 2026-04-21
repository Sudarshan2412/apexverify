import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

import '../models/match_snapshot.dart';

class OcrService {
  OcrService({
    http.Client? httpClient,
    String? cloudVisionApiKey,
    bool enableDebugLogs = false,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _cloudVisionApiKey = cloudVisionApiKey ?? _safeEnv('CLOUD_VISION_API_KEY'),
        _enableDebugLogs = enableDebugLogs;

  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final String _cloudVisionApiKey;
  final bool _enableDebugLogs;

  // ── Live pipeline state ──────────────────────────────────────
  StreamSubscription<Uint8List>? _liveFrameSub;
  final StreamController<MatchSnapshot> _snapshotController =
      StreamController<MatchSnapshot>.broadcast();

  /// The stream Member D subscribes to.
  /// Emits one [MatchSnapshot] per frame processed from the live pipeline.
  Stream<MatchSnapshot> get snapshotStream => _snapshotController.stream;

  Future<MatchSnapshot> processFrame(Uint8List frameBytes) async {
    final mlKitText = await _runMlKit(frameBytes);

    String bestText = mlKitText;
    if (isLowConfidence(mlKitText)) {
      final cloudVisionText = await _callCloudVision(frameBytes);
      if (cloudVisionText.trim().isNotEmpty) {
        bestText = cloudVisionText;
      }
    }

    return parseOcrString(bestText);
  }

  Future<String> debugGetRawOcrText(Uint8List frameBytes) async {
    final mlKitText = await _runMlKit(frameBytes);
    if (isLowConfidence(mlKitText)) {
      final cloudVisionText = await _callCloudVision(frameBytes);
      if (cloudVisionText.trim().isNotEmpty) {
        return cloudVisionText;
      }
    }
    return mlKitText;
  }

  bool isLowConfidence(String raw) {
    return raw.trim().length < 10 || !raw.contains(RegExp(r'\d'));
  }

  MatchSnapshot parseOcrString(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final compact = _extractCompactTeamScore(normalized);

    // Strategy 1: Look for dash-separated scores (TEAM N-N TEAM)
    final dashScores = RegExp(r'\b(\d{1,3})\s*-\s*(\d{1,3})\b')
        .allMatches(normalized)
        .toList();

    // Strategy 2: Look for space-separated scores (TEAM N N TEAM)
    final spacedScores = RegExp(r'\b(\d{1,3})\s+(\d{1,3})\b')
        .allMatches(normalized)
        .toList();

    // Strategy 3: Look for TEAM SCORE TEAM SCORE pattern (e.g., "NOP 107 LAC 124")
    final teamScorePattern = RegExp(r'\b([A-Z]{2,5})\s+(\d{1,3})\s+([A-Z]{2,5})\s+(\d{1,3})\b', caseSensitive: false)
        .firstMatch(normalized);

    // Find all clocks
    final clocks = RegExp(
      r"\b\d{1,3}(?:\+\d+)?'(?=\s|$)|\b\d{1,2}:\d{2}\b|:\d{2}\b|\b\d{1,2}\.\d{1,2}\b(?!\d)",
    ).allMatches(normalized).toList();

    // Resolve score with preference order
    String scoreText = '';
    _TeamNames teamNames = const _TeamNames('', '');

    if (compact != null) {
      scoreText = compact.score;
      teamNames = _TeamNames(compact.homeTeam, compact.awayTeam);
    } else if (dashScores.isNotEmpty) {
      scoreText = dashScores.first.group(0)!;
      teamNames = _extractTeamNames(normalized, scoreText);
    } else if (spacedScores.isNotEmpty) {
      // Filter out space-separated pairs that look like times
      for (final candidate in spacedScores) {
        final candText = candidate.group(0)!;
        if (!_looksLikeTime(candText, normalized)) {
          scoreText = candText;
          break;
        }
      }
      if (scoreText.isEmpty) {
        final isolatedScore = _extractScoreFromIsolatedNumbers(normalized);
        if (isolatedScore != null) {
          scoreText = isolatedScore;
        }
      }
      teamNames = _extractTeamNames(normalized, scoreText);
    } else if (teamScorePattern != null) {
      // Extract from TEAM SCORE TEAM SCORE pattern
      final home = (teamScorePattern.group(1) ?? '').toUpperCase();
      final away = (teamScorePattern.group(3) ?? '').toUpperCase();
      final score1 = teamScorePattern.group(2)!;
      final score2 = teamScorePattern.group(4)!;
      scoreText = '$score1 - $score2';
      teamNames = _TeamNames(home, away);
    } else {
      teamNames = _extractTeamCodes(normalized);
    }

    // Find clock (earliest one not part of the score)
    String clockText = '';
    for (final clock in clocks) {
      final clockStr = clock.group(0)!;
      if (!scoreText.contains(clockStr)) {
        clockText = clockStr;
        break;
      }
    }

    final hasOverlay = RegExp(
      r'https?://|www\.|wa\.me|\+\d{10,}|\b\d{3}[-\s]?\d{3}[-\s]?\d{4}\b',
      caseSensitive: false,
    ).hasMatch(normalized);

    // Format space-separated scores with dashes
    final formattedScore = _formatScore(scoreText);

    if (teamNames.homeTeam.isEmpty || teamNames.awayTeam.isEmpty) {
      final fallback = _extractTeamCodes(normalized);
      if (teamNames.homeTeam.isEmpty) {
        teamNames = _TeamNames(fallback.homeTeam, teamNames.awayTeam);
      }
      if (teamNames.awayTeam.isEmpty) {
        teamNames = _TeamNames(teamNames.homeTeam, fallback.awayTeam);
      }
    }

    return MatchSnapshot(
      homeTeam: teamNames.homeTeam,
      awayTeam: teamNames.awayTeam,
      score: formattedScore,
      clock: clockText,
      hasOverlay: hasOverlay,
    );
  }

  String _formatScore(String rawScore) {
    if (rawScore.isEmpty) return '';
    if (rawScore.contains('-') || rawScore.contains(':')) {
      return rawScore;
    }
    final parts = rawScore.trim().split(RegExp(r'\s+'));
    if (parts.length == 2) {
      return '${parts[0]} - ${parts[1]}';
    }
    return rawScore;
  }

  bool _looksLikeTime(String text, String context) {
    final idxInContext = context.indexOf(text);
    if (idxInContext < 0) return false;
    final before = idxInContext > 0 ? context[idxInContext - 1] : '';
    final after = idxInContext + text.length < context.length
        ? context[idxInContext + text.length]
        : '';
    return (before == ':' || after == ':' || after == '.' || before == '+' || after == '+');
  }

  Future<void> dispose() async {
    stopLivePipeline();
    await _snapshotController.close();
    try {
      await _textRecognizer.close();
    } on MissingPluginException {
      // ML Kit plugin may be unavailable on non-mobile targets.
    }
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LIVE PIPELINE — Member C Phase 3
  // ─────────────────────────────────────────────────────────────

  /// Starts the live OCR pipeline by subscribing to [frameStream].
  ///
  /// **How to use right now (mock, no Member B needed):**
  /// ```dart
  /// final sampler = RealMockFrameSampler();
  /// ocrService.startLivePipeline(sampler.startSampling(''));
  /// ```
  ///
  /// **When Member B is ready — one-line swap:**
  /// ```dart
  /// final sampler = FrameSampler(); // Member B's real frame grabber
  /// ocrService.startLivePipeline(sampler.startSampling(liveUrl));
  /// ```
  ///
  /// Member D subscribes to the output:
  /// ```dart
  /// ocrService.snapshotStream.listen(comparisonService.compare);
  /// ```
  void startLivePipeline(Stream<Uint8List> frameStream) {
    _liveFrameSub?.cancel();
    _liveFrameSub = frameStream.listen((frameBytes) async {
      final sw = Stopwatch()..start();
      try {
        final snapshot = await processFrame(frameBytes);
        sw.stop();
        final ms = sw.elapsedMilliseconds;
        _debug('Frame processed in ${ms}ms → $snapshot');
        if (ms > 5000) {
          _debug('⚠️ LATENCY WARNING: ${ms}ms exceeds 5000ms budget');
        }
        _snapshotController.add(snapshot);
      } catch (e) {
        sw.stop();
        _debug('Frame processing error (${sw.elapsedMilliseconds}ms): $e');
      }
    });
    _debug('Live pipeline started.');
  }

  /// Stops the live pipeline and cancels the frame subscription.
  /// Called automatically by [dispose].
  void stopLivePipeline() {
    _liveFrameSub?.cancel();
    _liveFrameSub = null;
    _debug('Live pipeline stopped.');
  }

  Future<String> _runMlKit(Uint8List frameBytes) async {
    File? frameFile;
    Directory? tempDir;
    try {
      frameFile = await _writeTempFrame(frameBytes);
      tempDir = frameFile.parent;
      final inputImage = InputImage.fromFilePath(frameFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (_) {
      return '';
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      } else if (frameFile != null && await frameFile.exists()) {
        await frameFile.delete();
      }
    }
  }

  Future<String> _callCloudVision(Uint8List frameBytes) async {
    if (_cloudVisionApiKey.isEmpty) {
      _debug('Cloud Vision skipped: CLOUD_VISION_API_KEY is empty.');
      return '';
    }

    final uri = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$_cloudVisionApiKey',
    );

    final body = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Encode(frameBytes)},
          'features': [
            {'type': 'TEXT_DETECTION'}
          ]
        }
      ]
    });

    try {
      final response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode != 200) {
        _debug('Cloud Vision HTTP ${response.statusCode}: ${_truncate(response.body)}');
        return '';
      }

      _debug('Cloud Vision HTTP 200 received.');

      final dynamic decoded = jsonDecode(response.body);
      final responses = decoded is Map<String, dynamic> ? decoded['responses'] : null;
      if (responses is! List || responses.isEmpty) {
        _debug('Cloud Vision response had no responses[] payload.');
        return '';
      }

      final first = responses.first;
      if (first is! Map<String, dynamic>) {
        _debug('Cloud Vision first response item was not a map.');
        return '';
      }

      final fullTextAnnotation = first['fullTextAnnotation'];
      if (fullTextAnnotation is! Map<String, dynamic>) {
        final textAnnotations = first['textAnnotations'];
        if (textAnnotations is List && textAnnotations.isNotEmpty) {
          final firstAnnotation = textAnnotations.first;
          if (firstAnnotation is Map<String, dynamic>) {
            final description = firstAnnotation['description'];
            _debug('Cloud Vision used textAnnotations fallback.');
            return description is String ? description : '';
          }
        }
        _debug('Cloud Vision had no fullTextAnnotation/textAnnotations text.');
        return '';
      }

      final text = fullTextAnnotation['text'];
      _debug('Cloud Vision used fullTextAnnotation text.');
      return text is String ? text : '';
    } catch (_) {
      _debug('Cloud Vision request failed due to network/parse exception.');
      return '';
    }
  }

  Future<File> _writeTempFrame(Uint8List frameBytes) async {
    final tempDir = await Directory.systemTemp.createTemp('fairscan_ocr_');
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}frame_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    return file.writeAsBytes(frameBytes, flush: true);
  }

  _TeamNames _extractTeamNames(String raw, String scoreText) {
    if (scoreText.isEmpty) {
      return const _TeamNames('', '');
    }

    final scoreIndex = raw.indexOf(scoreText);
    if (scoreIndex < 0) {
      return const _TeamNames('', '');
    }

    final beforeScore = raw.substring(0, scoreIndex).trim();
    final afterScore = raw.substring(scoreIndex + scoreText.length).trim();

    // Extract team names around the score
    final homeTeam = _extractTrailingTeam(beforeScore);
    final awayTeam = _extractLeadingTeam(afterScore);

    return _TeamNames(homeTeam, awayTeam);
  }

  _TeamNames _extractTeamCodes(String raw) {
    const noiseTokens = {
      'THE',
      'WORLD',
      'GAME',
      'LIVE',
      'SPORT',
      'SCORE',
      'MATCH',
    };

    final teams = RegExp(r'\b[A-Z]{2,5}\b', caseSensitive: false)
        .allMatches(raw)
        .map((m) => (m.group(0) ?? '').toUpperCase())
        .where((token) => token.isNotEmpty && !noiseTokens.contains(token))
        .toList();

    if (teams.length < 2) {
      return const _TeamNames('', '');
    }

    return _TeamNames(teams.first, teams.last);
  }

  _CompactTeamScore? _extractCompactTeamScore(String raw) {
    // MCI HESTER 0 89:10 0 TOT
    final withClockBetween = RegExp(
      r'\b([A-Z]{2,5})(?:\s+[A-Z]{2,}){0,2}\s+(\d{1,3})\s+\d{1,2}:\d{2}\s+(\d{1,3})\s+([A-Z]{2,5})\b',
      caseSensitive: false,
    ).firstMatch(raw);
    if (withClockBetween != null) {
      final home = (withClockBetween.group(1) ?? '').toUpperCase();
      final left = withClockBetween.group(2) ?? '';
      final right = withClockBetween.group(3) ?? '';
      final away = (withClockBetween.group(4) ?? '').toUpperCase();
      if (home.isNotEmpty && away.isNotEmpty && left.isNotEmpty && right.isNotEmpty) {
        return _CompactTeamScore(homeTeam: home, awayTeam: away, score: '$left - $right');
      }
    }

    // MCI 0 0 TOT
    final adjacent = RegExp(r'\b([A-Z]{2,5})\s+(\d{1,3})\s+(\d{1,3})\s+([A-Z]{2,5})\b')
        .firstMatch(raw);
    if (adjacent != null) {
      final home = (adjacent.group(1) ?? '').toUpperCase();
      final left = adjacent.group(2) ?? '';
      final right = adjacent.group(3) ?? '';
      final away = (adjacent.group(4) ?? '').toUpperCase();
      if (home.isNotEmpty && away.isNotEmpty && left.isNotEmpty && right.isNotEmpty) {
        return _CompactTeamScore(homeTeam: home, awayTeam: away, score: '$left - $right');
      }
    }

    // RMA 2 | 1 BAY or RMA 2 - 1 BAY
    final separated = RegExp(r'\b([A-Z]{2,5})\s+(\d{1,3})\s*[-|]\s*(\d{1,3})\s+([A-Z]{2,5})\b')
        .firstMatch(raw);
    if (separated != null) {
      final home = (separated.group(1) ?? '').toUpperCase();
      final left = separated.group(2) ?? '';
      final right = separated.group(3) ?? '';
      final away = (separated.group(4) ?? '').toUpperCase();
      if (home.isNotEmpty && away.isNotEmpty && left.isNotEmpty && right.isNotEmpty) {
        return _CompactTeamScore(homeTeam: home, awayTeam: away, score: '$left - $right');
      }
    }

    // NOP 107 LAC 124
    final split = RegExp(r'\b([A-Z]{2,5})\s+(\d{1,3})\s+([A-Z]{2,5})\s+(\d{1,3})\b', caseSensitive: false)
        .firstMatch(raw);
    if (split != null) {
      final home = (split.group(1) ?? '').toUpperCase();
      final left = split.group(2) ?? '';
      final away = (split.group(3) ?? '').toUpperCase();
      final right = split.group(4) ?? '';
      if (home.isNotEmpty && away.isNotEmpty && left.isNotEmpty && right.isNotEmpty) {
        return _CompactTeamScore(homeTeam: home, awayTeam: away, score: '$left - $right');
      }
    }

    return null;
  }

  String? _extractScoreFromIsolatedNumbers(String raw) {
    final matches = RegExp(r'\b\d{1,3}\b').allMatches(raw);
    final isolated = <String>[];

    for (final match in matches) {
      final start = match.start;
      final end = match.end;
      final before = start > 0 ? raw[start - 1] : '';
      final after = end < raw.length ? raw[end] : '';

      if (before == ':' || after == ':' || before == '.' || after == '.' || before == '+') {
        continue;
      }

      final token = match.group(0);
      if (token != null && token.isNotEmpty) {
        isolated.add(token);
      }
    }

    if (isolated.length < 2) {
      return null;
    }

    return '${isolated[0]} ${isolated[1]}';
  }

  String _extractTrailingTeam(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((word) => RegExp(r'^[A-Za-z]{2,}$').hasMatch(word))
        .toList();

    if (words.isEmpty) {
      return '';
    }

    if (words.length == 1) {
      return words.first.toUpperCase();
    }

    return '${words[words.length - 2]} ${words.last}'.toUpperCase();
  }

  String _extractLeadingTeam(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((word) => RegExp(r'^[A-Za-z]{2,}$').hasMatch(word))
        .toList();

    if (words.isEmpty) {
      return '';
    }

    if (words.length == 1) {
      return words.first.toUpperCase();
    }

    return '${words[0]} ${words[1]}'.toUpperCase();
  }

  static String _safeEnv(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  void _debug(String message) {
    if (_enableDebugLogs) {
      debugPrint('[OcrService] $message');
    }
  }

  String _truncate(String value) {
    const maxLen = 240;
    if (value.length <= maxLen) {
      return value;
    }
    return '${value.substring(0, maxLen)}...';
  }
}

class _TeamNames {
  const _TeamNames(this.homeTeam, this.awayTeam);

  final String homeTeam;
  final String awayTeam;
}

class _CompactTeamScore {
  const _CompactTeamScore({
    required this.homeTeam,
    required this.awayTeam,
    required this.score,
  });

  final String homeTeam;
  final String awayTeam;
  final String score;
}

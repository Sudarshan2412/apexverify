import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/match_snapshot.dart';
import '../models/violation_alert.dart';
import 'firestore_service.dart';

class ComparisonService {
  final FirestoreService _firestoreService;
  final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  // Step 3.2 Member D Step 5: Expose Stream<ViolationAlert?> to Member A
  // _alertController is broadcast so multiple listeners (dashboard, log) can subscribe.
  final StreamController<ViolationAlert?> _alertController =
      StreamController<ViolationAlert?>.broadcast();

  /// The alert stream Member A subscribes to in the dashboard.
  /// null = clean frame, non-null = violation detected.
  Stream<ViolationAlert?> get alertStream => _alertController.stream;

  ComparisonService(this._firestoreService);

  /// Step 3.2 Member D Step 1: Compare OCR snapshot against Firestore official data.
  ///
  /// Called from: `ocrService.snapshotStream.listen((snap) => comparisonService.compare(snap))`
  ///
  /// Checks score, clock drift, and overlay. Emits a ViolationAlert on mismatch
  /// or null on clean frame.
  Future<void> compare(MatchSnapshot ocr) async {
    final official = await _firestoreService.getOfficialData();

    // Step 3.2 Member D Step 2: Debug logging — Firestore vs OCR
    debugPrint('[ComparisonService] Official from Firestore: ${official['score']} vs OCR: ${ocr.score}');
    debugPrint('[ComparisonService] Official clock: ${official['clock']} vs OCR clock: ${ocr.clock}');

    // ── Score mismatch ──────────────────────────────────────────────────
    if (ocr.score.isNotEmpty && ocr.score != official['score']) {
      final alert = await _buildAlert(
        fieldMismatch: 'score',
        expected: official['score'] ?? '',
        actual: ocr.score,
      );
      _logAlert(alert);
      _alertController.add(alert);
      return;
    }

    // ── Clock drift ─────────────────────────────────────────────────────
    if (ocr.clock.isNotEmpty &&
        _clockDriftExceedsThreshold(ocr.clock, official['clock'] ?? '')) {
      final alert = await _buildAlert(
        fieldMismatch: 'clock',
        expected: official['clock'] ?? '',
        actual: ocr.clock,
      );
      _logAlert(alert);
      _alertController.add(alert);
      return;
    }

    // ── Overlay detection ───────────────────────────────────────────────
    if (ocr.hasOverlay) {
      final alert = await _buildAlert(
        fieldMismatch: 'overlay',
        expected: 'no overlay',
        actual: 'unauthorized overlay detected',
      );
      _logAlert(alert);
      _alertController.add(alert);
      return;
    }

    // Step 3.2 Member D Step 4: Clean frames produce null alerts
    debugPrint('[ComparisonService] Clean frame — no violations.');
    _alertController.add(null);
  }

  /// Step 3.2 Member D Step 3: Log all ViolationAlert fields for debugging.
  void _logAlert(ViolationAlert alert) {
    debugPrint('[ComparisonService] ⚠️ VIOLATION DETECTED:');
    debugPrint('  severity: ${alert.severity}');
    debugPrint('  fieldMismatch: ${alert.fieldMismatch}');
    debugPrint('  expected: ${alert.expected}');
    debugPrint('  actual: ${alert.actual}');
    debugPrint('  description: ${alert.description}');
    debugPrint('  timestamp: ${alert.timestamp}');
  }

  bool _clockDriftExceedsThreshold(String ocr, String official) {
    return (_parseClockToSeconds(ocr) - _parseClockToSeconds(official)).abs() > 60;
  }

  /// Converts a clock string to total seconds.
  /// Handles: "67'" → 4020s, "67:30" → 4050s, "49.8" → 50s
  int _parseClockToSeconds(String clock) {
    // Format: "67'" or "90+3'" (football)
    final prime = RegExp(r"(\d+)(?:\+\d+)?'").firstMatch(clock);
    if (prime != null) return int.parse(prime.group(1)!) * 60;
    // Format: "67:30" or "12:45" (MM:SS)
    final colon = RegExp(r'(\d+):(\d{2})').firstMatch(clock);
    if (colon != null) {
      return int.parse(colon.group(1)!) * 60 + int.parse(colon.group(2)!);
    }
    // Format: "49.8" (basketball quarter-clock in seconds)
    final decimal = double.tryParse(clock);
    if (decimal != null) return decimal.round();
    return 0;
  }

  Future<ViolationAlert> _buildAlert({
    required String fieldMismatch,
    required String expected,
    required String actual,
    Uint8List? frameBytes,
  }) async {
    final description = await _getGeminiDescription(
      fieldMismatch: fieldMismatch,
      expected: expected,
      actual: actual,
    );
    return ViolationAlert(
      severity: 'HIGH_RISK',
      description: description,
      fieldMismatch: fieldMismatch,
      expected: expected,
      actual: actual,
      timestamp: DateTime.now(),
      frameBytes: frameBytes,
    );
  }

  Future<String> _getGeminiDescription({
    required String fieldMismatch,
    required String expected,
    required String actual,
  }) async {
    final prompt = '''
A sports stream monitoring system detected a potential manipulation.
Field affected: $fieldMismatch
Official value: $expected
Value found in stream: $actual

In one sentence, describe this as a forensic finding for a DMCA report. Be specific and professional.
''';

    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      final json = jsonDecode(response.body);
      final text = json['candidates'][0]['content']['parts'][0]['text'];
      if (text == null || (text as String).trim().isEmpty) {
        debugPrint('[ComparisonService] ⚠️ Gemini returned null/empty description!');
        return 'Violation detected: $fieldMismatch mismatch (expected: $expected, actual: $actual).';
      }
      debugPrint('[ComparisonService] Gemini description received: ${text.substring(0, text.length.clamp(0, 80))}...');
      return text;
    } catch (e) {
      debugPrint('[ComparisonService] Gemini API call failed: $e');
      return 'Violation detected: $fieldMismatch mismatch (expected: $expected, actual: $actual).';
    }
  }

  void dispose() {
    _alertController.close();
  }
}

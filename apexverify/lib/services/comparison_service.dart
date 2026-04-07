import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/match_snapshot.dart';
import '../models/violation_alert.dart';
import 'firestore_service.dart';

class ComparisonService {
  final FirestoreService _firestoreService;
  final String geminiApiKey = 'AIzaSyCQSyLrDgOdzMsetp7jc1Qtu5z8UM_d6wo';

  final StreamController<ViolationAlert?> _alertController =
      StreamController<ViolationAlert?>.broadcast();

  Stream<ViolationAlert?> get alertStream => _alertController.stream;

  ComparisonService(this._firestoreService);

  Future<void> compare(MatchSnapshot ocr) async {
    final official = await _firestoreService.getOfficialData();

    if (ocr.score.isNotEmpty && ocr.score != official['score']) {
      _alertController.add(await _buildAlert(
        fieldMismatch: 'score',
        expected: official['score'],
        actual: ocr.score,
      ));
      return;
    }

    if (ocr.clock.isNotEmpty &&
        _clockDriftExceedsThreshold(ocr.clock, official['clock'])) {
      _alertController.add(await _buildAlert(
        fieldMismatch: 'clock',
        expected: official['clock'],
        actual: ocr.clock,
      ));
      return;
    }

    if (ocr.hasOverlay) {
      _alertController.add(await _buildAlert(
        fieldMismatch: 'overlay',
        expected: 'no overlay',
        actual: 'unauthorized overlay detected',
      ));
      return;
    }

    _alertController.add(null);
  }

  bool _clockDriftExceedsThreshold(String ocr, String official) {
    final ocrMin = int.tryParse(ocr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final offMin = int.tryParse(official.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return (ocrMin - offMin).abs() > 2;
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
    return json['candidates'][0]['content']['parts'][0]['text'] ??
        'Violation detected.';
  }
}
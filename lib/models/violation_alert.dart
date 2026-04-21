import 'dart:typed_data';

class ViolationAlert {
  final String severity;       // "HIGH_RISK" or "LOW_RISK"
  final String description;    // Gemini Flash plain-English description
  final String fieldMismatch;  // which field was wrong: "score", "clock", "overlay"
  final String expected;       // value from Firestore
  final String actual;         // value from OCR
  final DateTime timestamp;
  final Uint8List? frameBytes; // frame that triggered it (for DMCA screenshot)

  const ViolationAlert({
    required this.severity,
    required this.description,
    required this.fieldMismatch,
    required this.expected,
    required this.actual,
    required this.timestamp,
    this.frameBytes,
  });

  @override
  String toString() {
    return 'ViolationAlert(severity: $severity, fieldMismatch: $fieldMismatch, expected: $expected, actual: $actual, timestamp: $timestamp)';
  }
}

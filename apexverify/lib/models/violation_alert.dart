import 'dart:typed_data';

class ViolationAlert {
  final String severity;
  final String description;
  final String fieldMismatch;
  final String expected;
  final String actual;
  final DateTime timestamp;
  final Uint8List? frameBytes;

  ViolationAlert({
    required this.severity,
    required this.description,
    required this.fieldMismatch,
    required this.expected,
    required this.actual,
    required this.timestamp,
    this.frameBytes,
  });
}
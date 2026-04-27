import 'package:flutter/material.dart';
import '../../models/violation_alert.dart';

/// Shows violation details from Member D's ViolationAlert.
/// When [alert] is null, renders an "All Clear" placeholder.
class AlertCard extends StatelessWidget {
  final ViolationAlert? alert;
  const AlertCard({super.key, this.alert});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: alert == null ? const _CleanCard() : _ViolationCard(alert: alert!),
    );
  }
}

class _CleanCard extends StatelessWidget {
  const _CleanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('clean'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF1E1E1E)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ALERT', style: TextStyle(color: Color(0xFF444444), fontSize: 10, fontFamily: 'Courier New', letterSpacing: 2)),
          SizedBox(height: 8),
          Text('No violations detected', style: TextStyle(color: Color(0xFF333333), fontSize: 13)),
        ],
      ),
    );
  }
}

class _ViolationCard extends StatelessWidget {
  final ViolationAlert alert;
  const _ViolationCard({required this.alert});

  Color _severityColor() => switch (alert.severity.toUpperCase()) {
        'HIGH' => const Color(0xFFFF3B3B),
        'MEDIUM' => const Color(0xFFFFAA00),
        'HIGH_RISK' => const Color(0xFFFF3B3B),
        'LOW_RISK' => const Color(0xFFFFFF66),
        _ => const Color(0xFFFFFF66),
      };

  String _severityLabel() {
    final sev = alert.severity.toUpperCase();
    // Extract first word: "HIGH_RISK" → "HIGH", "MEDIUM" → "MEDIUM"
    return sev.split('_').first;
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();
    final ts = alert.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    return Container(
      key: const ValueKey('violation'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '⚠ ${_severityLabel()}',
                style: TextStyle(
                  color: color,
                  fontFamily: 'Courier New',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(timeStr, style: const TextStyle(color: Color(0xFF555555), fontFamily: 'Courier New', fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Field: ${alert.fieldMismatch}',
            style: const TextStyle(color: Color(0xFF888888), fontFamily: 'Courier New', fontSize: 11),
          ),
          const SizedBox(height: 8),
          // Gemini description from Member D
          Text(
            alert.description,
            style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

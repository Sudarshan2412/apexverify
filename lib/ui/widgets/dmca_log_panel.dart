import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/violation_alert.dart';
import '../../providers/alert_provider.dart';

/// Scrollable list of all ViolationAlerts received this session.
/// Appends automatically via DmcaLogNotifier in alert_provider.dart.
class DmcaLogPanel extends ConsumerWidget {
  const DmcaLogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(dmcaLogProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: const Color(0xFF1E1E1E)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'DMCA LOG',
                  style: TextStyle(
                    color: Color(0xFF555555),
                    fontFamily: 'Courier New',
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                if (log.isNotEmpty)
                  GestureDetector(
                    onTap: () => ref.read(dmcaLogProvider.notifier).clear(),
                    child: const Text(
                      'clear',
                      style: TextStyle(color: Color(0xFF444444), fontFamily: 'Courier New', fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1A1A1A)),

          // List
          Expanded(
            child: log.isEmpty
                ? const Center(
                    child: Text(
                      'No violations logged.',
                      style: TextStyle(color: Color(0xFF333333), fontFamily: 'Courier New', fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: log.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF141414)),
                    itemBuilder: (_, i) => _LogEntry(alert: log[i], index: i),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry extends StatelessWidget {
  final ViolationAlert alert;
  final int index;
  const _LogEntry({required this.alert, required this.index});

  @override
  Widget build(BuildContext context) {
    final ts = alert.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    final color = alert.severity.toUpperCase().contains('HIGH')
        ? const Color(0xFFFF3B3B)
        : const Color(0xFFFFAA00);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Text(
            '#${(index + 1).toString().padLeft(3, '0')}',
            style: const TextStyle(color: Color(0xFF333333), fontFamily: 'Courier New', fontSize: 10),
          ),
          const SizedBox(width: 10),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${alert.fieldMismatch} — ${alert.severity}',
              style: const TextStyle(color: Color(0xFF888888), fontFamily: 'Courier New', fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: const TextStyle(color: Color(0xFF444444), fontFamily: 'Courier New', fontSize: 10),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/frame_provider.dart';
import '../providers/alert_provider.dart';
import 'widgets/frame_preview_panel.dart';
import 'widgets/status_indicator.dart';
import 'widgets/alert_card.dart';
import 'widgets/dmca_log_panel.dart';

class StreamMonitorScreen extends ConsumerStatefulWidget {
  const StreamMonitorScreen({super.key});

  @override
  ConsumerState<StreamMonitorScreen> createState() => _StreamMonitorScreenState();
}

class _StreamMonitorScreenState extends ConsumerState<StreamMonitorScreen> {
  final TextEditingController _urlController = TextEditingController();

  void _submitUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    ref.read(streamUrlProvider.notifier).state = url;
  }

  Future<void> _saveScreenshot() async {
    final sampler = ref.read(frameSamplerProvider);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await sampler.saveCurrentFrame('apexverify_frame_$timestamp.png');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Frame saved: apexverify_frame_$timestamp.png')),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alertAsync = ref.watch(alertStreamProvider);
    final currentAlert = alertAsync.valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text(
          'ApexVerify',
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontFamily: 'Courier New',
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StatusIndicator(hasViolation: currentAlert != null),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── URL Input Row ──────────────────────────────────────────
            _UrlInputRow(
              controller: _urlController,
              onSubmit: _submitUrl,
              onSaveScreenshot: _saveScreenshot,
            ),
            const SizedBox(height: 20),

            // ── Main Content Row ───────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: frame preview
                  const Expanded(
                    flex: 3,
                    child: FramePreviewPanel(),
                  ),
                  const SizedBox(width: 20),

                  // Right: alert card + DMCA log
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        AlertCard(alert: currentAlert),
                        const SizedBox(height: 16),
                        const Expanded(child: DmcaLogPanel()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private sub-widget: URL input row ─────────────────────────────────────────
class _UrlInputRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onSaveScreenshot;

  const _UrlInputRow({
    required this.controller,
    required this.onSubmit,
    required this.onSaveScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Color(0xFFCCCCCC), fontFamily: 'Courier New'),
            decoration: InputDecoration(
              hintText: 'Paste stream URL (YouTube / Twitch)...',
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF00FF88)),
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF88),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: const Text('Monitor', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onSaveScreenshot,
          icon: const Icon(Icons.camera_alt_outlined, size: 16),
          label: const Text('Save Frame'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFAAAAAA),
            side: const BorderSide(color: Color(0xFF333333)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ],
    );
  }
}

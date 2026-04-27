import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'models/match_snapshot.dart';
import 'models/violation_alert.dart';
import 'providers/frame_provider.dart' show useMock;
import 'services/comparison_service.dart';
import 'services/firestore_service.dart';
import 'services/base_frame_sampler.dart';
import 'services/frame_sampler_factory.dart';
import 'services/ocr_service.dart';
import 'widgets/status_indicator.dart';
import 'widgets/alert_card.dart';
import 'widgets/dmca_log.dart';
import 'widgets/frame_preview_panel.dart';

/// StreamMonitorScreen - the main screen for Part 1
/// Optimized layout: smaller frame, better use of space
class StreamMonitorScreen extends StatefulWidget {
  const StreamMonitorScreen({super.key});

  @override
  State<StreamMonitorScreen> createState() => _StreamMonitorScreenState();
}

class _StreamMonitorScreenState extends State<StreamMonitorScreen> {
  final _urlController = TextEditingController(
    text: 'https://example.com/stream',
  );
  late BaseFrameSampler _frameSampler;
  Stream<Uint8List>? _frameStream;
  bool _isMonitoring = false;
  final List<ViolationAlert> _violations = [];

  // ── Live pipeline services (Step 3.1 + 3.2) ──────────────────────────
  late OcrService _ocrService;
  late ComparisonService _comparisonService;
  StreamSubscription<MatchSnapshot>? _snapshotSub;
  StreamSubscription<ViolationAlert?>? _alertSub;

  @override
  void initState() {
    super.initState();
    _frameSampler = createFrameSampler(useMock: useMock);
    _ocrService = OcrService(enableDebugLogs: true);
    _comparisonService = ComparisonService(FirestoreService());
  }

  @override
  void dispose() {
    _stopPipeline();
    _urlController.dispose();
    _frameSampler.dispose();
    _ocrService.dispose();
    _comparisonService.dispose();
    super.dispose();
  }

  void _startMonitoring() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Step 3.1 — Start the frame → OCR pipeline
    final frameStream = _frameSampler.startSampling(url);
    _frameStream = frameStream;
    _ocrService.startLivePipeline(frameStream);

    // Step 3.2 — Wire snapshotStream → ComparisonService
    _snapshotSub = _ocrService.snapshotStream.listen((MatchSnapshot snap) {
      debugPrint('Score: ${snap.score}');
      debugPrint('Clock: ${snap.clock}');
      debugPrint('Overlay: ${snap.hasOverlay}');
      _comparisonService.compare(snap);
    });

    // Listen for violation alerts from ComparisonService
    _alertSub = _comparisonService.alertStream.listen((alert) {
      if (alert != null && mounted) {
        setState(() {
          _violations.add(alert);
        });
      }
    });

    setState(() {
      _isMonitoring = true;
    });
  }

  void _stopMonitoring() {
    _stopPipeline();
    setState(() {
      _isMonitoring = false;
      _frameStream = null;
      _frameSampler.dispose();
      _frameSampler = createFrameSampler(useMock: useMock);
    });
  }

  void _stopPipeline() {
    _snapshotSub?.cancel();
    _snapshotSub = null;
    _alertSub?.cancel();
    _alertSub = null;
    _ocrService.stopLivePipeline();
  }

  Future<void> _saveScreenshot() async {
    await _frameSampler.saveCurrentFrame('monitor_screenshot.png');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Screenshot saved'),
          backgroundColor: AppColors.accentNeon,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _logout() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > 1200;
    final isMobile = screenSize.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.accentNeon),
            const SizedBox(width: 12),
            const Text('ApexVerify - Stream Monitor'),
            const Spacer(),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryBrand,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: AppColors.cardBackground,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: _isMonitoring
          ? _buildMonitoringView(context, isWideScreen, isMobile, screenSize)
          : _buildIdleView(context),
    );
  }

  Widget _buildIdleView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 0,
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link,
                          color: AppColors.accentNeon,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Stream Configuration',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 350,
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter stream URL',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.language),
                          prefixIconColor: AppColors.secondaryBrand,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.accentNeon,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _startMonitoring,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Monitoring'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentNeon,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringView(
    BuildContext context,
    bool isWideScreen,
    bool isMobile,
    Size screenSize,
  ) {
    if (isWideScreen) {
      // Ultra-wide: 4-column grid layout
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Control bar
            _buildControlBar(),
            const SizedBox(height: 16),
            // Main grid
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Frame (left column, small)
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 280,
                      child: FramePreviewPanel(
                          frameStream: _frameStream ?? const Stream<Uint8List>.empty(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Status + Alert (middle columns)
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        const Expanded(
                          child: StatusIndicator(),
                        ),
                        const SizedBox(height: 16),
                        const Expanded(
                          child: AlertCard(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // DMCA Log (right column)
                  Expanded(
                    flex: 1,
                    child: DMCALog(violations: _violations),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (!isMobile) {
      // Desktop/Tablet: 2 columns
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildControlBar(),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Frame + Status
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 260,
                          child: FramePreviewPanel(
                            frameStream: _frameStream ?? const Stream<Uint8List>.empty(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Expanded(
                          child: StatusIndicator(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right: Alert + Log
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        const Expanded(
                          child: AlertCard(),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: DMCALog(violations: _violations),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile: Stacked
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildControlBar(),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: FramePreviewPanel(
                  frameStream: _frameStream ?? const Stream<Uint8List>.empty(),
                ),
              ),
              const SizedBox(height: 12),
              const StatusIndicator(),
              const SizedBox(height: 12),
              const AlertCard(),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: DMCALog(violations: _violations),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildControlBar() {
    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                enabled: false,
                style: const TextStyle(color: Colors.white70),
                decoration: InputDecoration(
                  hintText: 'Stream URL',
                  prefixIcon: const Icon(Icons.language, size: 18),
                  prefixIconColor: AppColors.secondaryBrand,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _stopMonitoring,
              icon: const Icon(Icons.stop_circle),
              label: const Text('Stop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saveScreenshot,
              icon: const Icon(Icons.screenshot_monitor),
              label: const Text('Screenshot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

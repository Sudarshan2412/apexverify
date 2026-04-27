import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/frame_sampler.dart';
import '../core/theme/app_theme.dart';

/// Frame preview panel widget
/// Displays live frames from MockFrameSampler
class FramePreviewPanel extends StatefulWidget {
  final String url;
  final BaseFrameSampler frameSampler;

  const FramePreviewPanel({
    super.key,
    required this.url,
    required this.frameSampler,
  });

  @override
  State<FramePreviewPanel> createState() => _FramePreviewPanelState();
}

class _FramePreviewPanelState extends State<FramePreviewPanel> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.accentNeon.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: StreamBuilder<Uint8List>(
        stream: widget.frameSampler.startSampling(widget.url),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.videocam,
                        color: AppColors.accentNeon,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Live Frame Preview',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.videocam,
                      color: AppColors.accentNeon,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live Frame Preview',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentNeon.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.accentNeon,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Center(
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // The parent widget (StreamMonitorScreen) manages disposing the frame sampler.
    super.dispose();
  }
}

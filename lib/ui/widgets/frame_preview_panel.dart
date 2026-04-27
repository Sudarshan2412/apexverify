import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/frame_provider.dart';

class FramePreviewPanel extends ConsumerWidget {
  const FramePreviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameAsync = ref.watch(frameStreamProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF222222)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: frameAsync.when(
          data: (bytes) => _FrameImage(bytes: bytes),
          loading: () => const _PlaceholderBox(message: 'Waiting for stream...'),
          error: (e, _) => _PlaceholderBox(message: 'Stream error: $e'),
        ),
      ),
    );
  }
}

class _FrameImage extends StatelessWidget {
  final Uint8List bytes;
  const _FrameImage({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true, // prevents flicker on each new frame
        ),
        // Scanline overlay for aesthetic
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ScanlinePainter()),
          ),
        ),
        // Timestamp overlay (bottom-left)
        Positioned(
          bottom: 8,
          left: 10,
          child: Text(
            _timestamp(),
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontFamily: 'Courier New',
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }
}

class _PlaceholderBox extends StatelessWidget {
  final String message;
  const _PlaceholderBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Color(0xFF333333), size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF444444), fontFamily: 'Courier New', fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Light scanline effect — purely cosmetic
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08000000)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

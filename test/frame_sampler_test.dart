import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dark_pattern_detector/services/frame_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Asset loader shim ────────────────────────────────────────────────────
  // flutter_test does not load real assets by default.
  // This shim intercepts rootBundle.load() calls and reads from disk instead,
  // so the test works without a running Flutter engine.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(message.buffer.asUint8List());
      final file = File(key); // key == the asset path string
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      return ByteData.view(bytes.buffer);
    });
  });

  // ── RealMockFrameSampler tests ───────────────────────────────────────────
  group('RealMockFrameSampler', () {
    late RealMockFrameSampler sampler;

    setUp(() {
      sampler = RealMockFrameSampler(
        interval: const Duration(seconds: 2), // faster for tests
      );
    });

    tearDown(() {
      sampler.dispose();
    });

    // ── Test 1 ───────────────────────────────────────────────────────────
    test('emits at least one frame within 3 seconds', () async {
      final frames = <Uint8List>[];

      final sub = sampler.startSampling('mock://ignored').listen(frames.add);
      await Future.delayed(const Duration(seconds: 3));
      await sub.cancel();

      expect(frames, isNotEmpty,
          reason: 'Should have emitted at least one frame on the timer');
      print('✓ Received ${frames.length} frame(s)');
    });

    // ── Test 2 ───────────────────────────────────────────────────────────
    test('emitted bytes decode as a valid PNG image', () async {
      Uint8List? captured;

      final sub = sampler
          .startSampling('mock://ignored')
          .listen((f) => captured ??= f); // grab first frame only
      await Future.delayed(const Duration(seconds: 3));
      await sub.cancel();

      expect(captured, isNotNull, reason: 'No frame was emitted');

      final decoded = img.decodeImage(captured!);
      expect(decoded, isNotNull,
          reason: 'Emitted bytes should be a decodable PNG');
      print('✓ Valid PNG — ${decoded!.width}x${decoded.height}');
    });

    // ── Test 3 ───────────────────────────────────────────────────────────
    test('preprocessing converts image to grayscale (R == G == B at centre pixel)',
        () async {
      Uint8List? captured;

      final sub = sampler
          .startSampling('mock://ignored')
          .listen((f) => captured ??= f);
      await Future.delayed(const Duration(seconds: 3));
      await sub.cancel();

      expect(captured, isNotNull);

      final image = img.decodeImage(captured!)!;
      final cx = image.width ~/ 2;
      final cy = image.height ~/ 2;
      final pixel = image.getPixel(cx, cy);

      // In a grayscale image every channel is identical.
      expect(pixel.r, equals(pixel.g),
          reason: 'Grayscale: R should equal G at centre pixel');
      expect(pixel.g, equals(pixel.b),
          reason: 'Grayscale: G should equal B at centre pixel');

      print('✓ Grayscale confirmed — R=${pixel.r} G=${pixel.g} B=${pixel.b}');
    });

    // ── Test 4 ───────────────────────────────────────────────────────────
    test('cycles through multiple scoreboards (2 frames differ)', () async {
      final frames = <Uint8List>[];

      final sub = sampler.startSampling('mock://ignored').listen(frames.add);
      // Wait long enough to receive at least 2 emissions (interval = 2 s).
      await Future.delayed(const Duration(seconds: 5));
      await sub.cancel();

      expect(frames.length, greaterThanOrEqualTo(2),
          reason: 'Should have emitted at least 2 frames to confirm cycling');

      // Two consecutive frames from different assets should differ in byte length
      // (scoreboard images are different sizes). Not a perfect test but fast.
      final allSame = frames.every((f) => f.length == frames.first.length);
      expect(allSame, isFalse,
          reason: 'Frames from different scoreboards should differ');

      print('✓ Cycling confirmed — ${frames.length} frames emitted, lengths differ');
    });

    // ── Test 5 ───────────────────────────────────────────────────────────
    test('saveCurrentFrame writes a valid PNG file to disk', () async {
      const outPath = '/tmp/apexverify_test_save.png';

      final sub = sampler.startSampling('mock://ignored').listen((_) {});
      await Future.delayed(const Duration(seconds: 3));

      await sampler.saveCurrentFrame(outPath);
      await sub.cancel();

      final file = File(outPath);
      expect(await file.exists(), isTrue,
          reason: 'Output file should exist after saveCurrentFrame');

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100),
          reason: 'Saved file should not be empty');

      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull, reason: 'Saved file should be a valid PNG');

      print('✓ Saved PNG — ${bytes.length} bytes at $outPath');

      await file.delete();
    });
  });
}

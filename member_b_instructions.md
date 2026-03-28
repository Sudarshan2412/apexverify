# Frame Sampling Pipeline (Member B)

## Overview

The frame sampling pipeline is responsible for extracting frames from live sports streams, applying image preprocessing, and emitting them as a stream of bytes to the rest of the ApexVerify system. It sits between the live stream URL and the OCR engine — every frame Member C analyzes and every frame Member A displays passes through this pipeline first.

---

## Architecture

```
Live Stream URL
      │
      ▼
 FrameSampler
 (ffmpeg subprocess)
      │
      ▼
 _preprocess()
 ┌─────────────┐
 │  Grayscale  │
 │  Contrast   │  ← contrast: 1.5
 └─────────────┘
      │
      ▼
Stream<Uint8List>
 ┌─────────────┬──────────────┐
 │             │              │
 ▼             ▼              ▼
Member A    Member C      saveCurrentFrame()
(UI preview) (OCR engine) (DMCA screenshot)
```

---

## Files

| File | Purpose |
|---|---|
| `lib/services/frame_sampler.dart` | Core pipeline — all three classes live here |
| `test/services/frame_sampler_test.dart` | 5 unit tests validating the full pipeline |

---

## Classes

### `BaseFrameSampler` (abstract)
The shared interface that both the mock and real implementations conform to. Member A depends on this interface — swapping mock for real in Phase 3.1 is a single line change because both classes implement it identically.

```dart
abstract class BaseFrameSampler {
  Stream<Uint8List> startSampling(String url);
  Future<void> saveCurrentFrame(String outputPath);
  void dispose();
}
```

---

### `RealMockFrameSampler`
Used during Phase 2 for offline development and testing. Cycles through the four real sports broadcast screenshots in `assets/test_scoreboards/` on a 5-second timer, applying the same preprocessing as the live pipeline so Member C's OCR results on static images reflect real pipeline behaviour.

**Assets cycled:**
- `assets/test_scoreboards/nba_01.png`
- `assets/test_scoreboards/epl_01.png`
- `assets/test_scoreboards/epl_02.png`
- `assets/test_scoreboards/ucl_01.png`

```dart
final sampler = RealMockFrameSampler();
sampler.startSampling('mock://any').listen((Uint8List frameBytes) {
  // frameBytes is a preprocessed PNG — grayscale + contrast applied
});
```

---

### `FrameSampler`
The production implementation used from Phase 3.1 onwards. Uses `ffmpeg` as a subprocess to extract one frame every 5 seconds from a live YouTube or Twitch stream URL, then applies the same grayscale and contrast preprocessing before emitting.

```dart
final sampler = FrameSampler();
sampler.startSampling('https://your-stream-url').listen((Uint8List frameBytes) {
  // frameBytes ready for OCR and display
});
```

**Requires ffmpeg on the host machine:**
```powershell
# Windows
winget install ffmpeg

# Verify
ffmpeg -version
```

---

## Preprocessing

Every frame — whether from the mock or the live sampler — passes through the same two-step preprocessing before being emitted:

1. **Grayscale conversion** — removes color noise. Makes text/background separation easier for ML Kit, especially for white text on green grass or shadowed scoreboards.
2. **Contrast boost at 1.5** — brightens text against dark backgrounds. This specific value was agreed with Member C and directly improves OCR accuracy on broadcast frames.

```dart
final grayscale = img.grayscale(image);
final contrasted = img.adjustColor(grayscale, contrast: 1.5);
```

> **Note:** Do not change the contrast value without coordinating with Member C — their regex parser was tuned against output at this setting.

---

## Screenshot / DMCA Save

Member A calls `saveCurrentFrame(outputPath)` when the screenshot button is pressed. It writes the last emitted preprocessed frame to disk as a PNG.

```dart
await sampler.saveCurrentFrame('C:/apexverify/dmca/screenshot_001.png');
```

---

## Tests

```bash
flutter test test/services/frame_sampler_test.dart
```

| # | Test | What it validates |
|---|---|---|
| 1 | Emits within 3 seconds | Timer fires and stream produces output |
| 2 | Valid PNG bytes | Emitted bytes are a decodable image |
| 3 | Grayscale confirmed | Centre pixel has R == G == B |
| 4 | Cycling confirmed | Consecutive frames differ (different scoreboards) |
| 5 | Save to disk | `saveCurrentFrame()` writes a real PNG file |

All 5 tests passing as of Phase 2 completion.

---

## Phase 3.1 — Swapping Mock for Real

When Member B confirms ffmpeg is working against a live stream (Phase 3.1), Member A replaces one line in their provider:

```dart
// Phase 2 — mock
final sampler = RealMockFrameSampler();

// Phase 3.1 — real (one line change, interface identical)
final sampler = FrameSampler();
```

No other changes required in Member A's code.

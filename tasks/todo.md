# Task Tracker

## Phase Status
- Current phase: Phase 3 integration complete (Step 3.1 + Step 3.2 wired)
- Completed milestone: OCR service + parser + static image verification (4/4)
- Completed milestone: Live pipeline wiring (Step 3.1 + Step 3.2)

## Active Plan
- [x] Add `MatchSnapshot` model in `lib/models/match_snapshot.dart`.
- [x] Implement Part 1 OCR pipeline in `lib/services/ocr_service.dart`.
- [x] Add environment key loading for Cloud Vision API and document setup.
- [x] Add parser-focused tests for score/clock/overlay extraction.
- [x] Run verification (`flutter analyze` and relevant tests).

## Deploy Flutter Web to Vercel
- [x] Decide deploy mode: prebuilt upload (deploy `build/web`)
- [x] Build web bundle: `flutter build web --release`
- [x] Ensure SPA routing rewrite works (Vercel rewrite to `/index.html`)
- [x] Add Vercel proxy rewrite for `/api/*` → Render backend
- [x] Deploy `build/web` to Vercel (CLI)
- [ ] Verify production URL loads + deep links work
- [x] Confirm no secrets are shipped to the browser (do not bundle API keys)

## Deploy Backend (public)
- [x] Add Docker deploy files (ffmpeg + poppler + yt-dlp)
- [x] Deploy backend to Render (Docker) and get public URL
- [ ] Set `CORS_ORIGIN` to Vercel domain (optional if using Vercel same-origin `/api` proxy)
- [ ] Redeploy Render backend with latest `yt-dlp` resolver hardening
- [ ] Verify `GET /health` and `GET /api/frame?url=<youtubeUrl>&t=...` work (expect PNG 200)
- [x] Rebuild Flutter web (defaults to same-origin `/api/*`) and redeploy

## Phase 3 Integration Tasks

### Step 3.1 — Connect Frame Pipeline to OCR Engine (Member B + Member C)
- [x] FrameSampler class uncommented and compiles (`lib/services/frame_sampler.dart`)
- [x] RealMockFrameSampler class uncommented and compiles
- [x] BaseFrameSampler abstract interface active
- [x] frame_provider.dart: Replace stub classes with real imports from frame_sampler.dart
- [x] frame_provider.dart: Set `useMock = false` for Phase 3 live pipeline
- [x] ocr_provider.dart: Create provider wiring FrameSampler → OcrService.startLivePipeline → snapshotStream
- [x] stream_monitor_screen.dart: Wire _startMonitoring() to start live pipeline with frame → OCR → snapshot flow
- [x] stream_monitor_screen.dart: Add snapshotStream listener that prints Score/Clock/Overlay to console
- [x] OcrService.snapshotStream exposed as broadcast StreamController (already done)

### Step 3.2 — Connect OCR Output to Comparison Engine (Member C + Member D)
- [x] alert_provider.dart: Replace _stubAlertStream() with real ComparisonService.alertStream
- [x] alert_provider.dart: Create firestoreServiceProvider, comparisonServiceProvider
- [x] alert_provider.dart: Wire snapshotStream → ComparisonService.compare(snap) → alertStream
- [x] comparison_service.dart: Add debug logging for official vs OCR values
- [x] comparison_service.dart: Print ViolationAlert fields when Firestore mismatch occurs
- [x] comparison_service.dart: Expose Stream<ViolationAlert?> to Member A via broadcast controller

### Step 3.3 — Wire Alert Stream to Dashboard (Member D + Member A)
- [x] alert_provider.dart: Expose alertStreamProvider (Stream<ViolationAlert?>)
- [x] ui/stream_monitor_screen.dart: Confirm Member A can import and subscribe to alertStream without compile errors (`ref.watch(alertStreamProvider)`)
- [x] stream_monitor_screen.dart: StatusIndicator turns red on violation, green on null
- [x] stream_monitor_screen.dart: Wire ComparisonService.alertStream listener → _violations list

### Step 3.4 — Live Frame Sampling + Web Alternative (Phase 3)
- [x] Fix build break: ensure `.env` exists and is listed as a Flutter asset.
- [x] Fix “stuck on first frame” by avoiding sampler restarts caused by calling `startSampling()` from widget `build()`.
- [x] Verify Windows runtime: `flutter run -d windows` produces repeated `[FrameSampler] Frame grabbed ...` logs.
- [x] Start backend: `npm install` then `node src/server.js`, confirm `GET /health` works.
- [x] Verify web path: `flutter run -d chrome` compiles and processes frames via `/api/frame`.

## Workflow Compliance Tasks
- [ ] Start every non-trivial task by writing a checkable implementation plan in this file.
- [ ] If work goes sideways, stop and re-plan before continuing implementation.
- [ ] Mark progress during execution, not only at the end.
- [ ] Do not mark work complete until verification evidence is logged.
- [ ] After any user correction, add a prevention rule to `tasks/lessons.md`.
- [ ] Mirror tracker updates in both `tasks/*` and `fair_scan_ai/tasks/*` in the same turn.

## Remaining Part 1 Tasks
- [x] Run `flutter test test/ocr_service_test.dart` to verify parser fixes (dash, space-separated, TEAM SCORE TEAM SCORE patterns work)
- [x] Run `processFrame()` on each static image and validate output
- [x] Confirm no regressions in OCR logic
- [x] Verify decimal clock format (49.8) parsing works
- [x] Record final static-image validation results for handoff readiness
- [x] Isolate Member C work and coordination requirements in `integration.md`
- [x] Identify Member C remaining work and coordination gaps in `instructions.md`
- [x] Consolidate `integration.md` into deduplicated `instructions.md`, delete `integration.md`, and add `instructions.md` to `.gitignore`

## Review Notes (Part 1 Parser Debugging)
- Raw OCR from epl_01.png: "MCI HESTER 0 89:10 0 TOT HE WORLD'S GAME FC24 MANCHE THE WORLD'S" - Score was "0 0", clock "89:10". Parser found "89:10" as score (wrong). Fixed by removing `:` from dash-score regex (only `-` now).
- Raw OCR from nba_01.png: "ESPM GS 64 CLE 85 3RD 49.8 10 BONUS BONUS" - Should parse as GS vs CLE, 64-85, time 49.8. Parser missed decimal clock format. Fixed by adding `\b\d{1,2}\.\d{1,2}\b(?!\d)` to clock regex.
- Raw OCR from ucl_01.png: "90:00 9:34 +9 RMA 2 1 BAY (4-3)" - Should parse as RMA vs BAY, 2-1, clock 90:00. Parser picked "9:34" as score. Fixed by filtering space-separated candidates near `:` or `.`.
- Core fix: Implement 3-tier score detection: (1) dash-only, (2) space-separated with time-filtering, (3) TEAM SCORE TEAM SCORE pattern. Fallback to team code extraction.
- Additional fix: Handle OCR pattern `TEAM noise SCORE CLOCK SCORE TEAM` (e.g., `MCI HESTER 0 89:10 0 TOT`) with compact score extraction that tolerates a clock between score digits.
- Additional fix: Avoid score fallback to clock-like candidates; use isolated-number extraction and team-code fallback when team extraction from surrounding text is noisy.

## Verification Log
- `flutter test test/ocr_service_test.dart` -> pass
- `flutter analyze` -> no issues in project code
- `flutter run -d windows -t tool/ocr_static_check.dart` -> blocked by Windows symlink support (Developer Mode off)
- `flutter run -d windows -t tool/ocr_static_check.dart` -> runner starts, but snapshots empty (Cloud/desktop OCR path needs tuning)
- `flutter test test/ocr_service_test.dart` -> pass after adding space-separated scoreboard parsing support
- `flutter run -d windows -t tool/ocr_static_check.dart` -> `.env` found and API key detected, Cloud Vision returns HTTP 403 (billing disabled on GCP project)
- `flutter test test/ocr_service_test.dart` -> pass (8 tests) after adding noisy EPL regression test
- `flutter run -d windows -t tool/ocr_static_check.dart` -> pass on static images:
	- `epl_01.png` -> `MCI vs TOT`, score `0 - 0`, clock `89:10`
	- `epl_02.png` -> `ARS vs WOL`, score `0 - 0`, clock `24:35`
	- `nba_01.png` -> `GS vs CLE`, score `64 - 85`, clock `49.8`
	- `ucl_01.png` -> `RMA vs BAY`, score `2 - 1`, clock `90:00`
- `flutter run -d windows -t tool/ocr_static_check.dart` -> Cloud Vision escalation now succeeds with HTTP 200 and fullTextAnnotation across all static images; parsed snapshots confirmed for EPL/NBA/UCL samples
- `flutter analyze` -> 31 info-level issues (avoid_print, deprecated_member_use), 0 errors, 0 warnings in project code. Phase 3 wiring compiles cleanly.
- `flutter run -d windows` -> previously failed due to missing `.env` asset; fixed by adding local `.env` (gitignored). Windows build now completes and app starts.
- `flutter run -d windows` -> confirms frame sampling continues (multiple `Frame grabbed` entries, not just first frame).
- `npm install` (in repo root `fair_scan_ai/`) -> installs backend deps (dotenv/express/etc).
- `node fair_scan_ai/src/server.js` -> backend starts and serves `GET /health`.
- `Invoke-RestMethod http://localhost:3001/health` -> `{ "status": "OCR server is running", "port": 3001 }`.
- `Invoke-WebRequest /api/frame?...` -> saves PNG with signature `89 50 4E 47 0D 0A 1A 0A`.
- `/api/frame` advancing check -> hashes differ at `t=0/5/10`, confirming frames change over time (not stuck on first).
- `flutter run -d chrome` -> launches successfully; `[OcrService] Frame processed ...` repeats (web sampler path active).

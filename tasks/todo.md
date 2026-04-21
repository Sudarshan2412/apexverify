# Task Tracker

## Phase Status
- Current phase: Part 1 completed (static image validation and regex tuning)
- Completed milestone: OCR service + parser + static image verification (4/4)

## Active Plan
- [x] Add `MatchSnapshot` model in `lib/models/match_snapshot.dart`.
- [x] Implement Part 1 OCR pipeline in `lib/services/ocr_service.dart`.
- [x] Add environment key loading for Cloud Vision API and document setup.
- [x] Add parser-focused tests for score/clock/overlay extraction.
- [x] Run verification (`flutter analyze` and relevant tests).

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

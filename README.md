# AUTOKLINIK 3D CAMERA

## Current implementation
The current iOS app is a QR recognition prototype, **not** a wheel-alignment measuring system. It recognizes literal QR payloads AUTOKLINIK-3D-1 through AUTOKLINIK-3D-8. The newly printed ChArUco boards are NOT compatible with this scanner yet. No angle values from the current app are valid alignment measurements.

## Target hardware and user workflow (2026-11-24)
- Two-post vehicle lift, **four fixed reference boards** (two per post), and **four wheel-mounted boards**.
- One handheld iPhone camera moves around the vehicle; no fixed cameras.
- Screen shows the two posts, four reference boards, and four wheels with independent states: not seen / detected / geometrically validated.
- Step 1: create or select a lift calibration profile. Identify each reference board and establish their metric poses in a common reference frame; reading four IDs alone is NOT calibration.
- Step 2: mount wheel boards on rigid, repeatable adapters; detect each board.
- Step 3: rolling runout compensation from multiple wheel positions, with suitable vehicle support/procedure.
- Step 4: capture wheel poses with iPhone tracking registered to the lift reference frame; reject observations without sufficient tracking confidence.
- Step 5: steering sweep for caster; show camber/toe/caster only after algorithms and validation exist.

## ChArUco test board specification
Eight distinct 4x4 ChArUco boards generated with OpenCV DICT_4X4_250, 140 x 140 mm artwork at 100% print scale. Square size 35 mm, ArUco marker size 26 mm. Marker IDs per board: 0–7, 8–15, 16–23, 24–31, 32–39, 40–47, 48–55, 56–63. Board 1–4 reference; board 5–8 wheel. Print on matte stock and mount flat/rigid. The app must use the **same dictionary, dimensions, board-specific ID mapping and coordinate conventions**. Validate generated printouts and camera calibration before any measurement.

## Engineering milestones
1. Replace QR metadata scanner with camera video frames + ChArUco corner detection and board identification; show live preview and detection diagnostics.
2. Implement a two-post lift overview and guided reference board scan. Persist only IDs/observations initially; explicitly label metric calibration incomplete.
3. Calibrate iPhone intrinsics/distortion and metric reference geometry, including tracking/relocalization of moving phone. Evaluate drift and loss of tracking.
4. Implement one-wheel pose prototype and compare against reference instruments over repeated captures and phone paths.
5. Extend to four wheels, runout compensation, steering sweep, and uncertainty/repeatability reporting.

**Do not present unvalidated estimates as professional alignment readings.**

## Build
Codemagic workflow in codemagic.yaml is an unsigned iOS simulator compile test. A signed IPA for a physical iPhone needs separate signing and export configuration.

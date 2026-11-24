# AUTOKLINIK 3D CAMERA — vehicle validation protocol

## Current build
The app reads eight QR payloads `AUTOKLINIK-3D-1` … `AUTOKLINIK-3D-8` and provides preparation inputs. It **does not** measure wheel alignment. Do not use it to adjust a vehicle.

## Prerequisites before any numerical measurement
1. Record exact marker locations: which are fixed to the lift and which are rigidly fixed to each wheel, including orientation relative to the wheel plane.
2. Use fiducials with known corner coordinates and physical side lengths, not QR payload detection alone.
3. Calibrate the iPhone camera intrinsics and lens distortion at the capture resolution; lock focus/zoom and validate repeatability.
4. Recover each marker pose from four detected image corners using a calibrated perspective-n-point solver; reject ambiguous or high-reprojection-error results.
5. Establish a stable common 3D reference frame using surveyed fixed markers. For wheel-mounted targets, determine the target-to-wheel plane transform, compensate wheel runout, and account for steering angle.
6. Calculate camber and toe only from validated wheel plane normals and vehicle axes. A single image with only eight QR identities is insufficient.
7. Compare repeated results to a calibrated professional alignment rack, with several cars and steering positions, before displaying numerical results as actionable.

## First test on a vehicle (recognition only)
- Secure printed markers and record each marker's exact dimensions and placement.
- Scan all eight markers; check each appears once and can be reacquired after reset.
- Repeat from several camera positions and under workshop lighting.
- Record which targets become obscured or unreadable.
- **Do not** adjust toe/camber from this build.

## Build
`codemagic.yaml` defines `ios-marker-test` (simulator build) and `ios-iphone-unsigned` (unsigned IPA, requires a separate supported signing/install method). A successful build does not validate measurement accuracy.

## Engineering acceptance gates
- Camera calibration and corner-based pose estimation integrated and tested.
- Fixed marker geometry and wheel target transforms documented.
- Quality metrics and fail-closed handling for lost markers.
- Repeatability and comparison against certified equipment documented.
- Only then enable a numerical measurement screen.

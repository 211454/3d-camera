# AUTOKLINIK 3D Camera — marker layout and calibration specification

## Fixed lift markers (reference frame)
- Two-post lift: use rigid reference markers on both posts. Initial ID plan: L1 and L2 (not wheel markers). Consider multiple targets on each post for visibility and pose estimation.
- First-time calibration: physically measure required distances and orientations, calibrate camera intrinsics and save reference geometry and marker sizes to a locally stored profile.
- Start of every measurement: rescan fixed references, check sufficient observations and reprojection consistency; warn if markers are missing or shifted. Never silently reuse invalid calibration.
- Lift position, motion or fixture changes require revalidation; a two-marker observation alone is not enough to prove precise 3D calibration.

## Movable wheel markers
- Four wheel positions: W1 front-left, W2 front-right, W3 rear-left, W4 rear-right (viewed in vehicle's forward direction).
- Same physical printed targets/fixtures may be reused, but their pose must be measured for **every** car / scan. Do not save wheel poses as fixed reference calibration.
- Targets need rigid wheel mounting; perform runout compensation for actual wheel-angle estimation.
- Unique QR IDs are sufficient for the initial capture prototype, but QR detection by itself does not estimate validated 3D camber/toe. For metric geometry implement calibrated fiducials (AprilTag/ArUco), pose estimation and error checking.

## Russian / German prompts
- RU: «Проверьте маркеры на стойках подъёмника». DE: „Prüfen Sie die Markierungen an den Hebebühnensäulen.“
- RU: «Калибровка сохранена». DE: „Kalibrierung gespeichert.“
- RU: «Установите маркеры на четыре колеса». DE: „Bringen Sie die Marker an allen vier Rädern an.“
- RU: «Наведите камеру на маркер номер 1». DE: „Richten Sie die Kamera auf Marker Nummer 1.“
- RU: «Маркер найден». DE: „Marker erkannt.“
- RU: «Маркеры сместились. Повторите калибровку». DE: „Marker wurden verschoben. Kalibrieren Sie erneut.“

## Status
Design specification only. Existing iOS Swift prototype currently scans uniquely numbered QR markers 1–4 and speaks prompts, but does NOT yet persist a fixed-lift calibration or derive wheel angles. The two marker roles and their ID namespaces must be implemented in the scanner, then validated on a real two-post lift before use for vehicle alignment.

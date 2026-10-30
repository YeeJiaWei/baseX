# Display lock

`runXApp(lockTextScale: true, lockDisplaySize: true)` (both default `true`) makes the app ignore the OS accessibility sizing settings.

- `lockTextScale`: text scale is fixed at 1.0 (`TextScaler.noScaling`).
- `lockDisplaySize`: the app renders at the device's default density, ignoring Android Settings > Display size (`wm density`) and iOS Display Zoom.

## How it works

1. A native plugin (`basex/display` channel, method `zoomFactor`) returns `k` = current density / default density.
   - Android: `displayMetrics.densityDpi / DENSITY_DEVICE_STABLE` (both larger and smaller than 1).
   - iOS: `nativeScale / scale` when `nativeScale > scale` (Display Zoom), otherwise `1.0`.
   - Any other platform or error: `1.0`.
2. `XDisplayScale` fetches `k` before `runApp` and re-queries on `didChangeMetrics`, so changing the setting while the app runs is picked up. Skipped entirely when `lockDisplaySize` is false.
3. `XDisplayLock`, installed in `GetMaterialApp(builder:)`, lays the app out at the un-zoomed size (`size * k`, `devicePixelRatio / k`, insets `* k`) and scales it to the real screen with a `FittedBox`. Hit-testing goes through the transform, so touches stay correct.

## Known gaps

- iOS Plus-size iPhones downsample, so their zoomed mode is not detected (`nativeScale == scale`).
- iPad "More Space" is not normalised.
- Code reading `View.of(context)` or `PlatformDispatcher` sizes directly bypasses the lock; use `MediaQuery` instead.

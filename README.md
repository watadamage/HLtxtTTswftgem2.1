# HLtxtTTswft2.2

A native macOS accessibility utility that keeps a compact text-input window above normal application windows, then types the prepared text after a configurable two-to-ten-second focus delay.

## Run

```sh
swift run HLtxtTTswft2.2
```

The first execution requests **Accessibility** permission. Enable it in **System Settings → Privacy & Security → Accessibility**, then relaunch if needed. macOS may require a signed app bundle for the permission to persist between builds; the source is intentionally packaged as a Swift Package for easy inspection and iteration.

## Design safeguards

- Uses `NSWindow.Level.statusBar`, all-Spaces/full-screen collection behavior, and `hidesOnDeactivate = false` so the utility stays above ordinary and floating app windows without covering system alerts.
- Glass uses `NSVisualEffectView` as the actual window backdrop, while dark/light/system appearance is applied to the `NSWindow` itself.
- Opacity changes the full window consistently and has a 25% floor so controls remain usable.
- Focus changes pause typing by default; continuing after a focus change requires an explicit opt-in.

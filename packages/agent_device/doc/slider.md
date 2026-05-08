# Slider control

The `slider` command adjusts slider and picker elements. It targets
elements using the same selector/ref/coordinate system as `click`.

## CLI

```bash
# Set to an exact position (0.0 = min, 1.0 = max)
ad slider --position 0.5 'id=volumeSlider'

# Increment / decrement by steps
ad slider increment @e7
ad slider decrement --steps 3 'id=brightnessSlider'
```

## Library

```dart
// Set to 75%
await device.adjustSlider(
  normalizedPosition: 0.75,
  interactionTarget: InteractionTarget.selector('id=volumeSlider'),
);

// Increment by 2 steps
await device.adjustSlider(
  action: 'increment',
  steps: 2,
  interactionTarget: InteractionTarget.ref('@e7'),
);
```

## .ad replay scripts

```
slider --position 0.5 'id=volumeSlider'
slider increment @e7
slider decrement --steps 3 'id=brightnessSlider'
```

## How it works on iOS

The target is resolved to screen coordinates (via snapshot ref or
selector match), then the XCUITest runner applies the best strategy:

1. **Native `UISlider`** — uses `adjust(toNormalizedSliderPosition:)`
   for `--position`, or `normalizedSliderPosition` read + step for
   increment/decrement. Most precise.
2. **Flutter / custom sliders** — drags from the current thumb position
   (parsed from the accessibility value, e.g. `"50%"`) to the target
   position within the element rect. The rect is passed from Dart for
   accurate orientation detection. Elements taller than 80pt are treated
   as vertical.
3. **Picker wheels** (`UIDatePicker`, `UIPickerView`) — finds the
   nearest `XCUIElementTypePickerWheel` and taps one row above/below
   center to select the adjacent value. Works even when the accessibility
   inspector reports the element as `AXSlider` but XCUITest sees it as
   `.other`.
4. **Fallback** — taps 36pt left/right of the target coordinate for
   elements that don't match any pattern.

## How it works on Android

The target is resolved to coordinates the same way as iOS. Then:

1. **`--position`** — takes a snapshot to find the slider's bounding
   rect, computes the target x coordinate from the normalized position,
   and performs `adb shell input swipe` from the current position to
   the target.
2. **Increment/decrement** — performs a short horizontal swipe (50px)
   from the target coordinate in the appropriate direction.

## Supported element types

| Element                        | iOS                                    | Android            |
| ------------------------------ | -------------------------------------- | ------------------ |
| Native `UISlider` / `SeekBar`  | ✅ adjust(toNormalizedSliderPosition:) | ✅ adb input swipe |
| Flutter `Slider`               | ✅ drag gesture with value parsing     | ✅ adb input swipe |
| `UIDatePicker` wheel           | ✅ picker wheel tap                    | n/a                |
| Vertical slider (`RotatedBox`) | ✅ vertical drag                       | ✅ adb input swipe |

# Ambilight for macOS

A native macOS app that turns your monitor into an "Ambilight" setup: it captures the
screen in real time, computes the average color for a ring of zones around the screen
edges, and streams those colors over a serial (USB) connection to an Arduino driving a
WS2812B LED strip stuck to the back of the monitor.

```
Screen (captured) → average color per zone → serial (USB) → Arduino + FastLED → LED strip
```

## How it's built

| Layer | File(s) | Responsibility |
|---|---|---|
| Screen capture | `modern/ScreenCapture.swift`, `legacy/ScreenCaptureLegacy.swift` | Grabs frames from the display |
| Color extraction | `modern/ColorReader.swift`, `legacy/ColorReaderLegacy.swift` | Splits the frame edges into zones and averages the color of each |
| Serial output | `shared/ArduinoSender.swift` | Encodes colors into a byte packet and writes it to the serial port |
| Port discovery | `shared/ArduinoPathFinder.swift` | Auto-detects the Arduino's `/dev/cu.*` serial device |
| Preview window | `shared/AmbilightView.swift` | Optional on-screen window that mirrors the LED colors (for debugging without hardware) |
| Entry point | `modern/main.swift`, `legacy/main.swift` | Wires the pieces together and runs the app |
| Arduino firmware | `../arduino.ino` | Receives the color packet and drives the LED strip via FastLED |

There are **two variants** of the capture/color-reading code:

- **modern** — uses `ScreenCaptureKit` (GPU-accelerated). Requires **macOS 12.3+**. This is
  the recommended path on any reasonably recent Mac.
- **legacy** — uses `CGDisplayStream` (CPU-based, downscales to 160×90 before averaging,
  capped at 20 FPS). Requires **macOS 11.0+**. Use this on older macOS versions where
  ScreenCaptureKit isn't available. It also accepts an extra CLI argument (see below).

Both variants share the same Arduino-sending and port-discovery code in `shared/`.

## Requirements

- macOS 11.0+ (12.3+ recommended for the modern/ScreenCaptureKit build)
- Xcode Command Line Tools (`xcode-select --install`) — provides `swiftc`
- **Screen Recording permission** for your terminal/app in
  System Settings → Privacy & Security → Screen Recording (macOS will prompt on first run)
- An Arduino (or compatible board) wired to a WS2812B LED strip, flashed with `../arduino.ino`
- A USB serial connection to that Arduino

## Building

A `Makefile` is provided with targets for each architecture/variant:

```bash
make build-m1       # Apple Silicon, modern (ScreenCaptureKit)
make build-intel    # Intel Mac, modern (ScreenCaptureKit)
make build-legacy   # Intel target, legacy (CGDisplayStream, older macOS)
```

Each target compiles the relevant `ScreenCapture`/`ColorReader` pair plus the shared files
and `main.swift` into a single executable named `ambilight` in this directory.

To build and immediately run:

```bash
make run-m1
make run-intel
make run-legacy
```

To remove build output:

```bash
make clean
```

## Running

```bash
./ambilight
```

On startup the app:

1. Requests screen-capture access (grant it in System Settings if prompted, then re-run).
2. Auto-detects the Arduino's serial port by scanning `/dev` for known prefixes
   (`cu.usbmodem`, `cu.usbserial`, `cu.SLAB_USBtoUART`, `cu.wchusbserial`).
3. Opens the serial connection at 230400 baud and starts streaming colors.

There's no manual serial-port argument for the modern build — if your Arduino isn't
detected, check `ArduinoPathFinder.knownPrefixes` in `shared/ArduinoPathFinder.swift` and
add your device's prefix if needed (find it with `ls /dev/cu.*`).

### Legacy build: top/bottom padding

The legacy variant accepts one optional CLI argument — a padding (in pixels, scaled from a
1080p reference) to exclude from the top and bottom of the screen before computing zones.
Useful if you have letterboxing (e.g. ultrawide content, black bars) you don't want
influencing the LED colors:

```bash
./ambilight 40   # ignore the top/bottom 40px (at 1080p scale) when averaging
```

## LED layout / wiring

- 178 total LEDs: 32 on the left, 57 on top, 32 on the right, 57 on the bottom.
- Data starts at the **bottom of the left edge**, goes up, across the top (left→right),
  down the right edge, then across the bottom (right→left) — i.e. clockwise starting from
  bottom-left. This must match how the physical strip is wired to the Arduino.
- Arduino side (`../arduino.ino`): `LED_PIN 6`, `NUM_LEDS 178`, `BRIGHTNESS 160`, chipset
  `WS2812B`, color order `GRB`, serial baud `230400`.
- On boot, the Arduino runs a 3-second rainbow test animation, then fades out — useful to
  confirm wiring without the Mac app running.

To change the strip geometry (LED counts per side), update:
- `zonesLeftRight` / `zonesTopBottom` in `modern/main.swift` or `legacy/main.swift`
- `NUM_LEDS` in `../arduino.ino` (must equal `2×zonesLeftRight + 2×zonesTopBottom`)

## Serial protocol

Each frame is one packet:

```
[START_BYTE=255] [R,G,B × 178 LEDs] [END_BYTE=254]
```

- 1 + 178×3 + 1 = 536 bytes per packet.
- Color bytes with a raw value of 254 or 255 are clamped to 253 before sending, since 254
  and 255 are reserved as frame delimiters.
- The Mac app skips sending a new frame if the previous one is still being written
  (non-blocking, best-effort streaming — frames may be dropped under load, never queued).
- The Arduino (`../arduino.ino`) parses bytes between START/END, and only calls
  `FastLED.show()` if it received exactly the expected number of bytes — a truncated frame
  is silently discarded.

## Troubleshooting

| Problem | Fix |
|---|---|
| Nothing happens / no screen capture | Grant Screen Recording permission, then quit & relaunch |
| `⚠️ Arduino: cannotOpen(...)` | Check the board is plugged in and `ls /dev/cu.*` shows it; add its prefix to `ArduinoPathFinder` if unrecognized |
| LEDs don't light up | Confirm the boot rainbow test runs (power/wiring OK), check `LED_PIN`, and that `NUM_LEDS` matches the strip |
| Colors look wrong on one edge | Check the LED wiring order matches the clockwise-from-bottom-left layout above |
| Build fails on an older Mac | Use `make build-legacy` instead of `build-m1`/`build-intel` |
| Low/choppy FPS | Use the modern (ScreenCaptureKit) build; legacy is capped at 20 FPS by design |

## Related in this repo

- `../arduino.ino` — Arduino firmware (FastLED) that this app talks to.
- `../AmblightFullPng.swift` and `../swift-guide.md` — an older, single-file
  proof-of-concept Swift version (superseded by this modular app, kept for reference).
- `../index.ts`, `../serial_monitor.ts`, `../test_serial.ts` — a cross-platform Node.js
  implementation of the same idea (works on Windows/Linux, not just macOS).

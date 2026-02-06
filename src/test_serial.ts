/* =====================================
   AMBILIGHT - ОПТИМІЗОВАНИЙ КОД

   ПОРЯДОК LED СМУЖКИ:
   Зліва вверху → Справа вверху →
   Справа внизу → Зліва внизу → Зліва вверху

   Розподіл:
   - TOP (вверх): 57 LED (зліва-вверху до справа-вверху)
   - RIGHT (справа): 32 LED (вверху до внизу)
   - BOTTOM (низ): 57 LED (справа-внизу до зліва-внизу)
   - LEFT (зліва): 32 LED (внизу до вверху)
===================================== */

import { execSync } from 'child_process'
import sharp from 'sharp'
import { SerialPort } from 'serialport'
import * as fs from 'node:fs'

/* ════════════════════════════════════════
   КОНФІГУРАЦІЯ
════════════════════════════════════════ */

// LED конфігурація
const NUM_TOP = 57      // LED на верхній стороні (зліва → справа)
const NUM_RIGHT = 32    // LED на правій стороні (вверху → внизу)
const NUM_BOTTOM = 57   // LED на нижній стороні (справа → зліва)
const NUM_LEFT = 32     // LED на лівій стороні (внизу → вверху)
const TOTAL_LEDS = NUM_TOP + NUM_RIGHT + NUM_BOTTOM + NUM_LEFT // = 178

// Захоплення екрану
const CAPTURE_EDGE_THICKNESS = 10  // Скільки пікселів з краю захоплювати
const RESIZE_WIDTH = 320            // Ширина для обробки
const FPS = 30                      // Кадрів за секунду

// Serial порт
const SERIAL_PORT = '/dev/tty.usbserial-1320'
const BAUD_RATE = 115200

// Протокол
const START_BYTE = 255
const END_BYTE = 254

const FRAME_DATA_SIZE = TOTAL_LEDS * 3
const FRAME_SIZE = 1 + FRAME_DATA_SIZE + 1

/* ════════════════════════════════════════
   COLOR CORRECTION & GAMMA
════════════════════════════════════════ */

// Коригування для WS2812B
const COLOR_CORRECTION = {
  red: 1.0,
  green: 0.95,
  blue: 0.85,  // Менше синього
}

// Gamma correction
const GAMMA = 2.2
const gammaLUT = new Uint8Array(256)
for (let i = 0; i < 256; i++) {
  gammaLUT[i] = Math.round(Math.pow(i / 255, 1 / GAMMA) * 255)
}

function applyColorCorrection(r: number, g: number, b: number): [number, number, number] {
  r = Math.min(255, Math.round(r * COLOR_CORRECTION.red))
  g = Math.min(255, Math.round(g * COLOR_CORRECTION.green))
  b = Math.min(255, Math.round(b * COLOR_CORRECTION.blue))
  return [gammaLUT[r], gammaLUT[g], gammaLUT[b]]
}

/* ════════════════════════════════════════
   РОЗРАХУНОК КОЛЬОРІВ
════════════════════════════════════════ */

function averageColorFast(
  data: Buffer,
  width: number,
  channels: number,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
): [number, number, number] {
  let r = 0, g = 0, b = 0, count = 0
  const skip = 2

  for (let y = y1; y < y2; y += skip) {
    for (let x = x1; x < x2; x += skip) {
      const idx = (y * width + x) * channels
      r += data[idx]
      g += data[idx + 1]
      b += data[idx + 2]
      count++
    }
  }

  if (count === 0) return [0, 0, 0]

  r = Math.round(r / count)
  g = Math.round(g / count)
  b = Math.round(b / count)

  return applyColorCorrection(r, g, b)
}

/* ════════════════════════════════════════
   ЗАХОПЛЕННЯ ФРЕЙМУ (GPU)
════════════════════════════════════════ */

async function captureFrameOptimized(): Promise<Buffer> {
  try {
    // GPU захоплення (screencapture на Mac)
    execSync(`screencapture -x -m /tmp/frame.png`)
    const img = fs.readFileSync('/tmp/frame.png')

    const { data, info } = await sharp(img)
      .resize(RESIZE_WIDTH)
      .removeAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true })

    const { width, height, channels } = info

    const frame = Buffer.alloc(FRAME_SIZE)
    frame[0] = START_BYTE

    let offset = 1

    const pushRGB = (rgb: [number, number, number]) => {
      frame[offset++] = rgb[0]
      frame[offset++] = rgb[1]
      frame[offset++] = rgb[2]
    }

    /* ════════════════════════════════════════
       ПОРЯДОК: TOP → RIGHT → BOTTOM → LEFT

       Схема екрану:
       ┌────────────────────────────┐
       │ T0  T1  T2  T3  ...  T56   │ ← TOP (зліва → справа)
       │                            │
       │L31                      R0  │
       │L30                      R1  │
       │...         ЕКРАН         ...│ RIGHT (вверху → внизу)
       │L0                       R31 │
       │                            │
       │ B56  B55  ... B1  B0       │ ← BOTTOM (справа → зліва)
       └────────────────────────────┘
              LEFT (внизу → вверху)
    ════════════════════════════════════════ */

    // TOP (вверх) - від лівого краю до правого
    // x: 0 → width, y: 0 → CAPTURE_EDGE_THICKNESS
    for (let i = 0; i < NUM_TOP; i++) {
      const x1 = Math.floor((i / NUM_TOP) * width)
      const x2 = Math.floor(((i + 1) / NUM_TOP) * width)

      pushRGB(
        averageColorFast(
          data,
          width,
          channels,
          x1,
          0,
          x2,
          CAPTURE_EDGE_THICKNESS,
        ),
      )
    }

    // RIGHT (справа) - від верху до низу
    // x: width-THICKNESS → width, y: 0 → height
    for (let i = 0; i < NUM_RIGHT; i++) {
      const y1 = Math.floor((i / NUM_RIGHT) * height)
      const y2 = Math.floor(((i + 1) / NUM_RIGHT) * height)

      pushRGB(
        averageColorFast(
          data,
          width,
          channels,
          width - CAPTURE_EDGE_THICKNESS,
          y1,
          width,
          y2,
        ),
      )
    }

    // BOTTOM (низ) - від правого краю до лівого (В ЗВОРОТНОМУ ПОРЯДКУ!)
    // x: width → 0, y: height-THICKNESS → height
    for (let i = NUM_BOTTOM - 1; i >= 0; i--) {
      const x1 = Math.floor((i / NUM_BOTTOM) * width)
      const x2 = Math.floor(((i + 1) / NUM_BOTTOM) * width)

      pushRGB(
        averageColorFast(
          data,
          width,
          channels,
          x1,
          height - CAPTURE_EDGE_THICKNESS,
          x2,
          height,
        ),
      )
    }

    // LEFT (зліва) - від низу до верху (В ЗВОРОТНОМУ ПОРЯДКУ!)
    // x: 0 → CAPTURE_EDGE_THICKNESS, y: height → 0
    for (let i = NUM_LEFT - 1; i >= 0; i--) {
      const y1 = Math.floor((i / NUM_LEFT) * height)
      const y2 = Math.floor(((i + 1) / NUM_LEFT) * height)

      pushRGB(
        averageColorFast(
          data,
          width,
          channels,
          0,
          y1,
          CAPTURE_EDGE_THICKNESS,
          y2,
        ),
      )
    }

    frame[offset] = END_BYTE

    return frame
  } catch (err) {
    console.error('Capture error:', err)
    throw err
  }
}

/* ════════════════════════════════════════
   SERIAL PORT
════════════════════════════════════════ */

const port = new SerialPort({
  path: SERIAL_PORT,
  baudRate: BAUD_RATE,
})

port.on('open', () => {
  console.log('✓ Serial port opened:', SERIAL_PORT)
  console.log('🎬 Ambilight (GPU OPTIMIZED) running at', FPS, 'FPS')
  console.log('📐 LED Order: TOP(57) → RIGHT(32) → BOTTOM(57) → LEFT(32)')
  console.log('📊 Improvements:')
  console.log('  • Color correction enabled')
  console.log('  • Gamma correction enabled')
  console.log('  • GPU screen capture (screencapture)')
  console.log('  • Fast pixel sampling\n')
})

port.on('error', (err) => {
  console.error('Serial error:', err)
})

/* ════════════════════════════════════════
   MAIN LOOP
════════════════════════════════════════ */

let isProcessing = false
let frameCount = 0
let startTime = Date.now()

async function tick() {
  if (isProcessing) return
  if (!port.writable) return

  try {
    isProcessing = true

    const frame = await captureFrameOptimized()

    if (frame.length === FRAME_SIZE) {
      port.write(frame)
    }

    frameCount++

    // Статистика кожні 30 фреймів
    if (frameCount % 30 === 0) {
      const elapsed = (Date.now() - startTime) / 1000
      const actualFPS = (frameCount / elapsed).toFixed(1)
      console.log(`📊 Frame ${frameCount} | FPS: ${actualFPS}`)
    }
  } catch (err) {
    console.error('Frame error:', err)
  } finally {
    isProcessing = false
  }
}

function main() {
  console.log('Starting Ambilight...\n')
  setInterval(tick, 1000 / FPS)
}

main()

process.on('SIGINT', () => {
  console.log('\n\n❌ Ambilight stopped')
  port.close(() => {
    process.exit(0)
  })
})

/* ════════════════════════════════════════
   ДІАГРАМА LED РОЗТАШУВАННЯ:

   ┌─────────────────────────────────────┐
   │ 0   1   2  ...  55  56             │
   │                                     │
   │31                                0 │
   │30         ЕКРАН          1          │
   │...                      ...         │
   │1                         30         │
   │                                     │
   │56  55  54  ...  2   1  0           │
   └─────────────────────────────────────┘
        56  55  54  ... 1   0

   LED[0-56]:    TOP (зліва → справа)
   LED[57-88]:   RIGHT (вверху → внизу)
   LED[89-145]:  BOTTOM (справа → зліва)
   LED[146-177]: LEFT (внизу → вверху)


   РОЗБІР ДЛЯ ЕКРАНУ (1920x1080, після resize 320x240):

   TOP (57 LED):
   ├─ LED[0]:  X: 0-5.6px,    Y: 0-10px
   ├─ LED[1]:  X: 5.6-11px,   Y: 0-10px
   ├─ ...
   └─ LED[56]: X: 314.4-320px, Y: 0-10px

   RIGHT (32 LED):
   ├─ LED[57]:  X: 310-320px, Y: 0-7.5px
   ├─ LED[58]:  X: 310-320px, Y: 7.5-15px
   ├─ ...
   └─ LED[88]:  X: 310-320px, Y: 232.5-240px

   BOTTOM (57 LED) - В ЗВОРОТНОМУ ПОРЯДКУ:
   ├─ LED[89]:  X: 314.4-320px, Y: 230-240px (справа)
   ├─ LED[90]:  X: 308.8-314.4px, Y: 230-240px
   ├─ ...
   └─ LED[145]: X: 0-5.6px,     Y: 230-240px (зліва)

   LEFT (32 LED) - В ЗВОРОТНОМУ ПОРЯДКУ:
   ├─ LED[146]: X: 0-10px, Y: 232.5-240px (внизу)
   ├─ LED[147]: X: 0-10px, Y: 225-232.5px
   ├─ ...
   └─ LED[177]: X: 0-10px, Y: 0-7.5px (вверху)
════════════════════════════════════════ */
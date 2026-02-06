import screenshot from 'screenshot-desktop'
import sharp from 'sharp'
import { SerialPort } from 'serialport'

/* ================================
   CONFIG
================================ */

const NUM_TOP = 57
const NUM_SIDE = 32
const TOTAL_LEDS = 178

const CAPTURE_EDGE_THICKNESS = 10
const RESIZE_WIDTH = 320
const FPS = 20

const SERIAL_PORT = '/dev/tty.usbserial-1320'
const BAUD_RATE = 115200

const START_BYTE = 255
const END_BYTE = 254

const FRAME_DATA_SIZE = TOTAL_LEDS * 3
const FRAME_SIZE = 1 + FRAME_DATA_SIZE + 1

/* ================================
   SERIAL
================================ */

const port = new SerialPort({
  path: SERIAL_PORT,
  baudRate: BAUD_RATE,
})

port.on('open', () => {
  console.log('Serial port opened:', SERIAL_PORT)
})

port.on('error', (err) => {
  console.error('Serial error:', err)
})

/* ================================
   TYPES
================================ */

type RGB = [number, number, number]

/* ================================
   COLOR CALCULATION
================================ */

function averageColor(
  data: Buffer,
  width: number,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
): RGB {
  let r = 0
  let g = 0
  let b = 0
  let count = 0

  for (let y = y1; y < y2; y++) {
    for (let x = x1; x < x2; x++) {
      const idx = (y * width + x) * 3
      r += data[idx]
      g += data[idx + 1]
      b += data[idx + 2]
      count++
    }
  }

  if (count === 0) return [0, 0, 0]

  return [
    Math.round(r / count),
    Math.round(g / count),
    Math.round(b / count),
  ]
}

/* ================================
   FRAME CAPTURE
================================ */

async function captureFrame(): Promise<Buffer> {
  const img = await screenshot({ format: 'png' })

  const { data, info } = await sharp(img)
    .resize(RESIZE_WIDTH)
    .raw()
    .toBuffer({ resolveWithObject: true })

  const { width, height } = info

  const frame = Buffer.alloc(FRAME_SIZE)
  frame[0] = START_BYTE

  let offset = 1

  const pushRGB = (rgb: RGB) => {
    frame[offset++] = rgb[0]
    frame[offset++] = rgb[1]
    frame[offset++] = rgb[2]
  }

  // TOP
  for (let i = 0; i < NUM_TOP; i++) {
    const x1 = Math.floor((i / NUM_TOP) * width)
    const x2 = Math.floor(((i + 1) / NUM_TOP) * width)
    pushRGB(
      averageColor(data, width, x1, 0, x2, CAPTURE_EDGE_THICKNESS),
    )
  }

  // RIGHT
  for (let i = 0; i < NUM_SIDE; i++) {
    const y1 = Math.floor((i / NUM_SIDE) * height)
    const y2 = Math.floor(((i + 1) / NUM_SIDE) * height)
    pushRGB(
      averageColor(
        data,
        width,
        width - CAPTURE_EDGE_THICKNESS,
        y1,
        width,
        y2,
      ),
    )
  }

  // BOTTOM
  for (let i = 0; i < NUM_TOP; i++) {
    const x1 = Math.floor((i / NUM_TOP) * width)
    const x2 = Math.floor(((i + 1) / NUM_TOP) * width)
    pushRGB(
      averageColor(
        data,
        width,
        x1,
        height - CAPTURE_EDGE_THICKNESS,
        x2,
        height,
      ),
    )
  }

  // LEFT
  for (let i = 0; i < NUM_SIDE; i++) {
    const y1 = Math.floor((i / NUM_SIDE) * height)
    const y2 = Math.floor(((i + 1) / NUM_SIDE) * height)
    pushRGB(
      averageColor(
        data,
        width,
        0,
        y1,
        CAPTURE_EDGE_THICKNESS,
        y2,
      ),
    )
  }

  frame[offset] = END_BYTE

  return frame
}

/* ================================
   MAIN LOOP
================================ */

let isProcessing = false

async function tick() {
  if (isProcessing) return
  if (!port.writable) return

  try {
    isProcessing = true

    const frame = await captureFrame()

    if (frame.length === FRAME_SIZE) {
      port.write(frame)
    }
  } catch (err) {
    console.error('Frame error:', err)
  } finally {
    isProcessing = false
  }
}

function main() {
  console.log('Ambilight started at', FPS, 'FPS')

  setInterval(tick, 1000 / FPS)
}

main()
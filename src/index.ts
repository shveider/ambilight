import screenshot from 'screenshot-desktop'
import sharp from 'sharp'
import { SerialPort } from 'serialport'

const NUM_TOP = 57
const NUM_SIDE = 32
const TOTAL_LEDS = 178

const CAPTURE_EDGE_THICKNESS = 10
const RESIZE_WIDTH = 320
const FPS = 20

const SERIAL_PORT = '/dev/tty.usbserial-1320'

const port = new SerialPort({
  path: SERIAL_PORT,
  baudRate: 115200,
})

type RGB = [number, number, number];

function averageColor(
  data: Buffer,
  width: number,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
): RGB {
  let r = 0,
    g = 0,
    b = 0,
    count = 0

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

async function captureFrame(): Promise<Buffer> {
  const img = await screenshot({format: 'png'})

  const {data, info} = await sharp(img)
    .resize(RESIZE_WIDTH)
    .raw()
    .toBuffer({resolveWithObject: true})

  const {width, height} = info

  const frame: number[] = []
  frame.push(255) // start byte

  // TOP
  for (let i = 0; i < NUM_TOP; i++) {
    const x1 = Math.floor((i / NUM_TOP) * width)
    const x2 = Math.floor(((i + 1) / NUM_TOP) * width)
    const rgb = averageColor(data, width, x1, 0, x2, CAPTURE_EDGE_THICKNESS)
    frame.push(...rgb)
  }

  // RIGHT
  for (let i = 0; i < NUM_SIDE; i++) {
    const y1 = Math.floor((i / NUM_SIDE) * height)
    const y2 = Math.floor(((i + 1) / NUM_SIDE) * height)
    const rgb = averageColor(
      data,
      width,
      width - CAPTURE_EDGE_THICKNESS,
      y1,
      width,
      y2,
    )
    frame.push(...rgb)
  }

  // BOTTOM
  for (let i = 0; i < NUM_TOP; i++) {
    const x1 = Math.floor((i / NUM_TOP) * width)
    const x2 = Math.floor(((i + 1) / NUM_TOP) * width)
    const rgb = averageColor(
      data,
      width,
      x1,
      height - CAPTURE_EDGE_THICKNESS,
      x2,
      height,
    )
    frame.push(...rgb)
  }

  // LEFT
  for (let i = 0; i < NUM_SIDE; i++) {
    const y1 = Math.floor((i / NUM_SIDE) * height)
    const y2 = Math.floor(((i + 1) / NUM_SIDE) * height)
    const rgb = averageColor(
      data,
      width,
      0,
      y1,
      CAPTURE_EDGE_THICKNESS,
      y2,
    )
    frame.push(...rgb)
  }

  return Buffer.from(frame)
}

async function main() {
  setInterval(async () => {
    try {
      const frame = await captureFrame()
      port.write(frame)
    } catch (err) {
      console.error('Frame error:', err)
    }
  }, 1000 / FPS)
}

void main()
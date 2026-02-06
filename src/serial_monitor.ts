import { SerialPort, ReadlineParser } from 'serialport'

const SERIAL_PORT = '/dev/tty.usbserial-1320'
const BAUD_RATE = 115200

const port = new SerialPort({
  path: SERIAL_PORT,
  baudRate: BAUD_RATE,
})

const parser = port.pipe(new ReadlineParser({ delimiter: '\n' }))

port.on('open', () => {
  console.log('Serial Monitor opened:', SERIAL_PORT)
  console.log('-----------------------------------')
})

parser.on('data', (data) => {
  console.log(data)
})

port.on('error', (err) => {
  console.error('Serial error:', err.message)
})

process.on('SIGINT', () => {
  console.log('\n-----------------------------------')
  console.log('Serial Monitor closed')
  port.close(() => {
    process.exit(0)
  })
})
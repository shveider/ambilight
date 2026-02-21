import Foundation

class ArduinoSender {

    private let START_BYTE: UInt8 = 255
    private let END_BYTE: UInt8   = 254

    private var serialPort: FileHandle?
    private let portPath: String

    init(portPath: String) {
        self.portPath = portPath
    }

    // MARK: - Connect

    func connect() throws {
        // Відкриваємо serial port
        let fd = open(portPath, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd != -1 else {
            throw SerialError.cannotOpen(portPath)
        }

        // Налаштовуємо baudrate 115200
        var options = termios()
        tcgetattr(fd, &options)

        cfsetispeed(&options, speed_t(B115200))
        cfsetospeed(&options, speed_t(B115200))

        // 8N1 — 8 біт, без парності, 1 стоп біт
        options.c_cflag &= ~UInt(PARENB)
        options.c_cflag &= ~UInt(CSTOPB)
        options.c_cflag &= ~UInt(CSIZE)
        options.c_cflag |=  UInt(CS8)
        options.c_cflag |=  UInt(CREAD | CLOCAL)

        // Raw mode
        options.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ISIG)
        options.c_iflag &= ~UInt(IXON | IXOFF | IXANY)
        options.c_oflag &= ~UInt(OPOST)

        tcsetattr(fd, TCSANOW, &options)

        serialPort = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        print("✅ Підключено до Arduino: \(portPath)")

        // Чекаємо поки Arduino перезавантажиться після підключення
        Thread.sleep(forTimeInterval: 2.0)
    }

    // MARK: - Send Frame

    func sendColors(_ colors: [RGB]) {
        guard let port = serialPort else { return }
        guard colors.count == 178 else {
            print("⚠️ Очікується 178 кольорів, отримано \(colors.count)")
            return
        }

        // Формуємо пакет: START + 178*3 байти RGB + END
        var packet = Data()
        packet.reserveCapacity(1 + 178 * 3 + 1)

        packet.append(START_BYTE)

        for rgb in colors {
            // Якщо значення == 255 або 254 — зменшуємо на 1
            // щоб не конфліктувати зі START/END байтами
            packet.append(clamp(rgb.r))
            packet.append(clamp(rgb.g))
            packet.append(clamp(rgb.b))
        }

        packet.append(END_BYTE)

        port.write(packet)
    }

    // MARK: - Disconnect

    func disconnect() {
        serialPort?.closeFile()
        serialPort = nil
        print("⛔ Відключено від Arduino")
    }

    // MARK: - Helpers

    // 255 і 254 зарезервовані як START/END — замінюємо на 253
    private func clamp(_ value: UInt8) -> UInt8 {
        if value >= 254 { return 253 }
        return value
    }

    // MARK: - Errors

    enum SerialError: Error {
        case cannotOpen(String)
    }
}

import Foundation

class ArduinoSender {

    private let START_BYTE: UInt8 = 255
    private let END_BYTE: UInt8   = 254

    private var serialPort: FileHandle?
    private let portPath: String

    // Окрема черга для відправки
    private let sendQueue = DispatchQueue(label: "arduino.send", qos: .userInteractive)

    // Якщо true — відправка ще йде, пропускаємо кадр
    private var isSending = false

    init(portPath: String) {
        self.portPath = portPath
    }

    // MARK: - Connect

    func connect() throws {
        // Прибираємо O_NONBLOCK — порт має блокувати якщо буфер заповнений
        let fd = open(portPath, O_RDWR | O_NOCTTY)
        guard fd != -1 else {
            throw SerialError.cannotOpen(portPath)
        }

        var options = termios()
        tcgetattr(fd, &options)

        cfsetispeed(&options, speed_t(B230400))
        cfsetospeed(&options, speed_t(B230400))

        options.c_cflag &= ~UInt(PARENB)
        options.c_cflag &= ~UInt(CSTOPB)
        options.c_cflag &= ~UInt(CSIZE)
        options.c_cflag |=  UInt(CS8)
        options.c_cflag |=  UInt(CREAD | CLOCAL)

        options.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ISIG)
        options.c_iflag &= ~UInt(IXON | IXOFF | IXANY)
        options.c_oflag &= ~UInt(OPOST)

        tcsetattr(fd, TCSANOW, &options)

        serialPort = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        print("✅ Підключено до Arduino: \(portPath)")

        Thread.sleep(forTimeInterval: 2.0)
    }

    // MARK: - Send Frame

    func sendColors(_ colors: [RGB]) {
        guard let serialPort else { return }

        var packet = Data(capacity: colors.count * 3)

        for rgb in colors {
            packet.append(rgb.r)
            packet.append(rgb.g)
            packet.append(rgb.b)
        }

        serialPort.write(packet)
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

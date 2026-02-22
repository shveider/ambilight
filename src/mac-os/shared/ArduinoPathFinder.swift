import Foundation

class ArduinoPathFinder {

    private let knownPrefixes = ["cu.usbmodem", "cu.usbserial", "cu.SLAB_USBtoUART", "cu.wchusbserial"]
    private let devDir = "/dev"

    // MARK: - Find

    func findPort() -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: devDir) else { return nil }

        for prefix in knownPrefixes {
            if let match = files.first(where: { $0.hasPrefix(prefix) }) {
                return "\(devDir)/\(match)"
            }
        }

        return nil
    }

    func findAllPorts() -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: devDir) else { return [] }

        return knownPrefixes.flatMap { prefix in
            files
            .filter { $0.hasPrefix(prefix) }
            .map { "\(devDir)/\($0)" }
        }
    }

    // MARK: - Has

    func hasArduino() -> Bool {
        findPort() != nil
    }

    func hasMultipleDevices() -> Bool {
        findAllPorts().count > 1
    }
}
SOURCES_COMMON = AmbilightView.swift ArduinoPathFinder.swift ArduinoSender.swift main.swift
OUTPUT = ambilight

# macOS 12.3+ (M1, Intel Monterey+)
build:
	swiftc -O ScreenCapture.swift ColorReader.swift $(SOURCES_COMMON) -o $(OUTPUT)

# macOS 11 Big Sur (Intel)
build-bigsur:
	swiftc -O ScreenCaptureLegacy.swift ColorReaderLegacy.swift $(SOURCES_COMMON) -o $(OUTPUT)

run: build
	./$(OUTPUT)

run-bigsur: build-bigsur
	./$(OUTPUT)

clean:
	rm -f $(OUTPUT)
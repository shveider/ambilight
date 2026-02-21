SOURCES_COMMON = AmbilightView.swift ArduinoPathFinder.swift ArduinoSender.swift main.swift
OUTPUT = ambilight

# macOS 12.3+ (M1, Intel Monterey+)
build:
	swiftc -O -target arm64-apple-macos12.3 ScreenCapture.swift ColorReader.swift AmbilightView.swift ArduinoPathFinder.swift ArduinoSender.swift main.swift -o ambilight-arm64
	swiftc -O -target x86_64-apple-macos12.3 ScreenCapture.swift ColorReader.swift AmbilightView.swift ArduinoPathFinder.swift ArduinoSender.swift main.swift -o ambilight-x86
	lipo -create ambilight-arm64 ambilight-x86 -output ambilight
	rm ambilight-arm64 ambilight-x86

# macOS 11 Big Sur (Intel)
build-bigsur:
	swiftc -O ScreenCaptureLegacy.swift ColorReaderLegacy.swift $(SOURCES_COMMON) -o $(OUTPUT)

run: build
	./$(OUTPUT)

run-bigsur: build-bigsur
	./$(OUTPUT)

clean:
	rm -f $(OUTPUT)
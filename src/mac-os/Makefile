SOURCES_COMMON = AmbilightView.swift ArduinoPathFinder.swift ArduinoSender.swift main.swift
OUTPUT = ambilight

# M1 (arm64)
build-m1:
	swiftc -O ScreenCapture.swift ColorReader.swift $(SOURCES_COMMON) -o $(OUTPUT)

# Intel Monterey+ (x86_64)
build-intel:
	swiftc -O -target x86_64-apple-macos12.3 ScreenCapture.swift ColorReader.swift $(SOURCES_COMMON) -o $(OUTPUT)

# Big Sur Intel
build-bigsur:
	swiftc -O ScreenCaptureLegacy.swift ColorReaderLegacy.swift $(SOURCES_COMMON) -o $(OUTPUT)

run-m1: build-m1
	./$(OUTPUT)

run-intel: build-intel
	./$(OUTPUT)

clean:
	rm -f $(OUTPUT)
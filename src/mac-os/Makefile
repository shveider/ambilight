SHARED = shared/AmbilightView.swift shared/ArduinoSender.swift shared/ArduinoPathFinder.swift shared/main.swift
OUTPUT = ambilight

build-m1:
	swiftc -O -target arm64-apple-macos12.3 modern/ScreenCapture.swift modern/ColorReader.swift $(SHARED) -o $(OUTPUT)

build-intel:
	swiftc -O -target x86_64-apple-macos12.3 modern/ScreenCapture.swift modern/ColorReader.swift $(SHARED) -o $(OUTPUT)

build-legacy:
	swiftc -O -suppress-warnings -target x86_64-apple-macos11.0 legacy/ScreenCaptureLegacy.swift  legacy/ColorReaderLegacy.swift $(SHARED) -o $(OUTPUT)

run-m1: build-m1
	./$(OUTPUT)

run-intel: build-intel
	./$(OUTPUT)

run-legacy: build-legacy
	./$(OUTPUT)

clean:
	rm -f $(OUTPUT)
	rm -rf Ambilight.app
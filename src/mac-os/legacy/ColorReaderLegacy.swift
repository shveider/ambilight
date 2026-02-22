import CoreGraphics
import Foundation

struct RGB {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

class ColorReader {

    let zonesLeftRightCount: Int  // 32
    let zonesTopBottomCount: Int  // 57
    let stripThicknessCount: Int  // 10

    // Загальна кількість зон
    var totalZones: Int { (zonesLeftRightCount * 2) + (zonesTopBottomCount * 2) }

    init(zonesLeftRight: Int = 32, zonesTopBottom: Int = 57, stripThickness: Int = 10) {
        self.zonesLeftRightCount = zonesLeftRight
        self.zonesTopBottomCount = zonesTopBottom
        self.stripThicknessCount = stripThickness
    }

    // MARK: - Головна функція
    // Повертає масив RGB по годинниковій стрілці:
    // [0...31]   LEFT:   знизу вгору
    // [32...88]  TOP:    зліва направо
    // [89...120] RIGHT:  зверху вниз
    // [121...177] BOTTOM: справа наліво

    func readColors(from image: CGImage) -> [RGB] {
        let width = image.width
        let height = image.height

        // Захоплюємо тільки крайові смуги — не весь екран
        guard
        let leftStrip  = image.cropping(to: CGRect(x: 0, y: 0, width: stripThicknessCount, height: height)),
        let rightStrip = image.cropping(to: CGRect(x: width - stripThicknessCount, y: 0, width: stripThicknessCount, height: height)),
        let topStrip   = image.cropping(to: CGRect(x: 0, y: 0, width: width, height: stripThicknessCount)),
        let bottomStrip = image.cropping(to: CGRect(x: 0, y: height - stripThicknessCount, width: width, height: stripThicknessCount))
        else { return [] }

        guard
        let leftPixels   = getRawPixels(from: leftStrip),
        let rightPixels  = getRawPixels(from: rightStrip),
        let topPixels    = getRawPixels(from: topStrip),
        let bottomPixels = getRawPixels(from: bottomStrip)
        else { return [] }

        var results = [RGB]()
        results.reserveCapacity(totalZones)

        // LEFT: знизу вгору — читаємо з leftStrip (ширина = stripThicknessCount)
        for i in 0..<zonesLeftRightCount {
            let flipped = zonesLeftRightCount - 1 - i
            let zoneHeight = height / zonesLeftRightCount
            let rect = CGRect(x: 0, y: flipped * zoneHeight, width: stripThicknessCount, height: zoneHeight)
            results.append(averageColor(in: rect, pixels: leftPixels, imageWidth: stripThicknessCount))
        }

        // TOP: зліва направо — читаємо з topStrip (висота = stripThicknessCount)
        for i in 0..<zonesTopBottomCount {
            let zoneWidth = width / zonesTopBottomCount
            let rect = CGRect(x: i * zoneWidth, y: 0, width: zoneWidth, height: stripThicknessCount)
            results.append(averageColor(in: rect, pixels: topPixels, imageWidth: width))
        }

        // RIGHT: зверху вниз — читаємо з rightStrip
        for i in 0..<zonesLeftRightCount {
            let zoneHeight = height / zonesLeftRightCount
            let rect = CGRect(x: 0, y: i * zoneHeight, width: stripThicknessCount, height: zoneHeight)
            results.append(averageColor(in: rect, pixels: rightPixels, imageWidth: stripThicknessCount))
        }

        // BOTTOM: справа наліво — читаємо з bottomStrip
        for i in 0..<zonesTopBottomCount {
            let flipped = zonesTopBottomCount - 1 - i
            let zoneWidth = width / zonesTopBottomCount
            let rect = CGRect(x: flipped * zoneWidth, y: 0, width: zoneWidth, height: stripThicknessCount)
            results.append(averageColor(in: rect, pixels: bottomPixels, imageWidth: width))
        }

        return results
    }

    // MARK: - Середній колір

    private func averageColor(in rect: CGRect, pixels: [UInt8], imageWidth: Int) -> RGB {
        var totalR = 0, totalG = 0, totalB = 0, count = 0

        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                let offset = (y * imageWidth + x) * 4
                totalR += Int(pixels[offset])
                totalG += Int(pixels[offset + 1])
                totalB += Int(pixels[offset + 2])
                count += 1
            }
        }

        guard count > 0 else { return RGB(r: 0, g: 0, b: 0) }
        return RGB(r: UInt8(totalR / count), g: UInt8(totalG / count), b: UInt8(totalB / count))
    }

    // MARK: - Сирі пікселі

    private func getRawPixels(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}
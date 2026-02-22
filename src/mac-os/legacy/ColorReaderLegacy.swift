import CoreGraphics
import Foundation

struct RGB {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

class ColorReader {

    let zonesLeftRightCount: Int
    let zonesTopBottomCount: Int
    let stripThicknessCount: Int
    let topBottomPadding: Int

    private let downscaleWidth = 160
    private let downscaleHeight = 90

    private var smallBuffer: [UInt8] = []

    init(zonesLeftRight: Int, zonesTopBottom: Int, stripThickness: Int, topBottomPadding: Int = 0) {
        self.zonesLeftRightCount = zonesLeftRight
        self.zonesTopBottomCount = zonesTopBottom
        self.stripThicknessCount = stripThickness
        self.topBottomPadding = topBottomPadding
    }

    func readColors(displayID: CGDirectDisplayID) -> [RGB] {

        guard let image = CGDisplayCreateImage(displayID) else { return [] }

        downscale(image: image)

        return calculateZones()
    }

    private func downscale(image: CGImage) {

        let needed = downscaleWidth * downscaleHeight * 4
        if smallBuffer.count != needed {
            smallBuffer = [UInt8](repeating: 0, count: needed)
        }

        guard let context = CGContext(
            data: &smallBuffer,
            width: downscaleWidth,
            height: downscaleHeight,
            bitsPerComponent: 8,
            bytesPerRow: downscaleWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0,
            width: downscaleWidth,
            height: downscaleHeight))
    }

    private func calculateZones() -> [RGB] {

        var results: [RGB] = []
        results.reserveCapacity((zonesLeftRightCount * 2) + (zonesTopBottomCount * 2))

        let w = downscaleWidth
        let h = downscaleHeight

        let scaledPadding = max(0, min(h / 2,
            topBottomPadding * h / 1080))

        let activeTop = scaledPadding
        let activeBottom = h - scaledPadding
        let activeHeight = activeBottom - activeTop

        let t = max(1, stripThicknessCount * h / 1080)

        // ---------------- LEFT (знизу вгору) ----------------
        for i in 0..<zonesLeftRightCount {
            let flipped = zonesLeftRightCount - 1 - i

            let startY = activeTop + (activeHeight * flipped) / zonesLeftRightCount
            let endY   = activeTop + (activeHeight * (flipped + 1)) / zonesLeftRightCount

            results.append(
                avgRect(
                    x: 0,
                    y: startY,
                    width: t,
                    height: endY - startY
                )
            )
        }

        // ---------------- TOP (зліва направо) ----------------
        for i in 0..<zonesTopBottomCount {

            let startX = (w * i) / zonesTopBottomCount
            let endX   = (w * (i + 1)) / zonesTopBottomCount

            results.append(
                avgRect(
                    x: startX,
                    y: activeTop,
                    width: endX - startX,
                    height: t
                )
            )
        }

        // ---------------- RIGHT (зверху вниз) ----------------
        for i in 0..<zonesLeftRightCount {

            let startY = activeTop + (activeHeight * i) / zonesLeftRightCount
            let endY   = activeTop + (activeHeight * (i + 1)) / zonesLeftRightCount

            results.append(
                avgRect(
                    x: w - t,
                    y: startY,
                    width: t,
                    height: endY - startY
                )
            )
        }

        // ---------------- BOTTOM (справа наліво) ----------------
        for i in 0..<zonesTopBottomCount {

            let flipped = zonesTopBottomCount - 1 - i

            let startX = (w * flipped) / zonesTopBottomCount
            let endX   = (w * (flipped + 1)) / zonesTopBottomCount

            results.append(
                avgRect(
                    x: startX,
                    y: activeBottom - t,
                    width: endX - startX,
                    height: t
                )
            )
        }

        return results
    }

    private func avgRect(x: Int, y: Int, width: Int, height: Int) -> RGB {

        var r = 0, g = 0, b = 0, count = 0

        for yy in y..<min(y+height, downscaleHeight) {
            for xx in x..<min(x+width, downscaleWidth) {
                let offset = (yy * downscaleWidth + xx) * 4
                r += Int(smallBuffer[offset])
                g += Int(smallBuffer[offset+1])
                b += Int(smallBuffer[offset+2])
                count += 1
            }
        }

        guard count > 0 else { return RGB(r: 0, g: 0, b: 0) }

        return RGB(
            r: UInt8(r / count),
            g: UInt8(g / count),
            b: UInt8(b / count)
        )
    }
}
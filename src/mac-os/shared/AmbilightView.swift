import AppKit
import CoreGraphics
import QuartzCore

class AmbilightWindow: NSWindow {

    private let borderView = AmbilightBorderView()

    init(width: CGFloat = 900, height: CGFloat = 560) {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = "Ambilight Preview"
        isReleasedWhenClosed = false
        backgroundColor = .black

        borderView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        borderView.autoresizingMask = [.width, .height]
        contentView?.addSubview(borderView)
    }

    func updateColors(_ colors: [RGB]) {
        DispatchQueue.main.async { [weak self] in
            self?.borderView.updateColors(colors)
        }
    }
}

class AmbilightBorderView: NSView {

    private let leftRightCount = 32
    private let topBottomCount = 57
    private let segmentThickness: CGFloat = 20

    private var zoneLayers: [CALayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupLayersIfNeeded(width: CGFloat, height: CGFloat) {
        guard zoneLayers.isEmpty else { return }

        let sideSegH = height / CGFloat(leftRightCount)
        let topSegW  = width  / CGFloat(topBottomCount)

        // LEFT: знизу вгору — layer[0] фізично внизу
        for i in 0..<leftRightCount {
            let l = makeLayer()
            l.frame = CGRect(x: 0, y: CGFloat(i) * sideSegH, width: segmentThickness, height: sideSegH)
            layer?.addSublayer(l)
            zoneLayers.append(l)
        }

        // TOP: зліва направо — layer[0] фізично зліва, у NSView верх = height
        for i in 0..<topBottomCount {
            let l = makeLayer()
            l.frame = CGRect(x: CGFloat(i) * topSegW, y: height - segmentThickness, width: topSegW, height: segmentThickness)
            layer?.addSublayer(l)
            zoneLayers.append(l)
        }

        // RIGHT: зверху вниз — layer[0] фізично вгорі (flipped)
        for i in 0..<leftRightCount {
            let flipped = leftRightCount - 1 - i
            let l = makeLayer()
            l.frame = CGRect(x: width - segmentThickness, y: CGFloat(flipped) * sideSegH, width: segmentThickness, height: sideSegH)
            layer?.addSublayer(l)
            zoneLayers.append(l)
        }

        // BOTTOM: справа наліво — layer[0] фізично справа (flipped)
        for i in 0..<topBottomCount {
            let flipped = topBottomCount - 1 - i
            let l = makeLayer()
            l.frame = CGRect(x: CGFloat(flipped) * topSegW, y: 0, width: topSegW, height: segmentThickness)
            layer?.addSublayer(l)
            zoneLayers.append(l)
        }
    }

    private func makeLayer() -> CALayer {
        let l = CALayer()
        l.actions = ["backgroundColor": NSNull()]
        return l
    }

    func updateColors(_ colors: [RGB]) {
        setupLayersIfNeeded(width: bounds.width, height: bounds.height)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, rgb) in colors.enumerated() {
            guard i < zoneLayers.count else { break }
            zoneLayers[i].backgroundColor = CGColor(
                red:   CGFloat(rgb.r) / 255.0,
                green: CGFloat(rgb.g) / 255.0,
                blue:  CGFloat(rgb.b) / 255.0,
                alpha: 1.0
            )
        }

        CATransaction.commit()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        zoneLayers.forEach { $0.removeFromSuperlayer() }
        zoneLayers.removeAll()
    }
}
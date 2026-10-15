import AppKit
struct Composition {
    static let presets: [(String, Double)] = [("Story 9:16", 9.0/16), ("Portrait 4:5", 0.8), ("Portrait 3:4", 0.75), ("Square 1:1", 1), ("Landscape 1.91:1", 1.91), ("Landscape 16:9", 16.0/9), ("Original", 0), ("Custom", -1)]
    var preset = "Story 9:16"
    var customWidth = 9.0
    var customHeight = 16.0
    var borders = false
    var blurred = false
    var color = NSColor.white
    var blur = 24.0
    var horizontalPadding = 0.05
    var verticalPadding = 0.05
    var zoom = 1.0
    // Positive angles rotate clockwise, matching the editor's top-left coordinates.
    var rotation = 0.0
    var rotationRadians: Double { (rotation.isFinite ? rotation : 0) * .pi / 180 }
    var offset = CGSize.zero
    mutating func rotate(by degrees: Double, image: CGSize) {
        let value = rotation + degrees
        rotation = value.isFinite ? value.truncatingRemainder(dividingBy: 360) : 0
        constrainOffset(image: image)
    }
    func rotatedSize(image: CGSize) -> CGSize {
        let c = abs(cos(rotationRadians)), s = abs(sin(rotationRadians))
        return CGSize(width: image.width * c + image.height * s,
                      height: image.width * s + image.height * c)
    }
    func ratio(image: CGSize) -> Double {
        let value = Self.presets.first { $0.0 == preset }?.1 ?? 9.0/16
        if value == 0 { let size = rotatedSize(image: image); return size.width / size.height }
        if value == -1 { return max(0.1, min(20, customWidth / max(0.1, customHeight))) }
        return value
    }
    func frame(image: CGSize, canvas: CGSize) -> CGRect {
        let available = CGSize(width: canvas.width * (1 - 2 * horizontalPadding), height: canvas.height * (1 - 2 * verticalPadding))
        let c = cos(rotationRadians), s = sin(rotationRadians)
        let bounds = rotatedSize(image: image)
        // Project the canvas onto the photo's axes so Fill covers every corner.
        let projectedWidth = canvas.width * abs(c) + canvas.height * abs(s)
        let projectedHeight = canvas.width * abs(s) + canvas.height * abs(c)
        let scale = (borders ? min(available.width / bounds.width, available.height / bounds.height)
                     : max(projectedWidth / image.width, projectedHeight / image.height)) * zoom
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        var x = offset.width * canvas.width, y = offset.height * canvas.height
        if !borders {
            let limitX = max(0, (size.width - projectedWidth) / 2)
            let limitY = max(0, (size.height - projectedHeight) / 2)
            let localX = max(-limitX, min(limitX, c * x + s * y))
            let localY = max(-limitY, min(limitY, -s * x + c * y))
            x = c * localX - s * localY
            y = s * localX + c * localY
        }
        return CGRect(x: (canvas.width-size.width)/2+x, y: (canvas.height-size.height)/2+y, width: size.width, height: size.height)
    }
    mutating func constrainOffset(image: CGSize) {
        guard !borders else { return }
        let canvas = CGSize(width: 1000, height: 1000 / ratio(image: image))
        let rect = frame(image: image, canvas: canvas)
        offset = CGSize(width: (rect.midX - canvas.width / 2) / canvas.width, height: (rect.midY - canvas.height / 2) / canvas.height)
    }
    mutating func pan(by delta: CGSize, canvas: CGSize, image: CGSize) {
        guard canvas.width > 0, canvas.height > 0,
              canvas.width.isFinite, canvas.height.isFinite,
              delta.width.isFinite, delta.height.isFinite else { return }
        offset.width += delta.width / canvas.width
        offset.height += delta.height / canvas.height
        constrainOffset(image: image)
    }
    func outputSize(width: Int, image: CGSize) -> CGSize {
        let outputWidth = min(Double(max(1, width)), floor(8192 * ratio(image: image)))
        return CGSize(width: outputWidth, height: max(1.0, (outputWidth / ratio(image: image)).rounded()))
    }
}

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
    var offset = CGSize.zero
    func ratio(image: CGSize) -> Double {
        let value = Self.presets.first { $0.0 == preset }?.1 ?? 9.0/16
        if value == 0 { return image.width / image.height }
        if value == -1 { return max(0.1, min(20, customWidth / max(0.1, customHeight))) }
        return value
    }
    func frame(image: CGSize, canvas: CGSize) -> CGRect {
        let available = CGSize(width: canvas.width * (1 - 2 * horizontalPadding), height: canvas.height * (1 - 2 * verticalPadding))
        let scale = (borders ? min(available.width / image.width, available.height / image.height) : max(canvas.width / image.width, canvas.height / image.height)) * zoom
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        let x = borders ? offset.width * canvas.width : max(-(size.width-canvas.width)/2, min((size.width-canvas.width)/2, offset.width * canvas.width))
        let y = borders ? offset.height * canvas.height : max(-(size.height-canvas.height)/2, min((size.height-canvas.height)/2, offset.height * canvas.height))
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

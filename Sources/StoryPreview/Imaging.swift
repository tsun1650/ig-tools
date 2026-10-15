import AppKit
import ImageIO
import UniformTypeIdentifiers
import CoreImage
struct Photo: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let size: CGSize
}
enum Imaging {
    static let context = CIContext()
    static func photo(_ url: URL) -> Photo? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary), CGImageSourceGetCount(source) == 1,
              let type = CGImageSourceGetType(source), let uti = UTType(type as String), !uti.conforms(to: .rawImage),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Double, let h = props[kCGImagePropertyPixelHeight] as? Double, w > 0, h > 0 else { return nil }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        return Photo(url: url, size: orientation >= 5 ? CGSize(width: h, height: w) : CGSize(width: w, height: h))
    }
    static func load(_ url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [(maxPixel <= 512 ? kCGImageSourceCreateThumbnailFromImageIfAbsent : kCGImageSourceCreateThumbnailFromImageAlways): true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel, kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
    static func render(image: CGImage, composition: Composition, size: CGSize) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor((composition.color.usingColorSpace(.sRGB) ?? .white).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        if composition.borders && composition.blurred {
            let rotated = CIImage(cgImage: image).transformed(by: CGAffineTransform(rotationAngle: -composition.rotationRadians))
            let input = rotated.transformed(by: CGAffineTransform(translationX: -rotated.extent.minX, y: -rotated.extent.minY))
            let s = max(size.width/input.extent.width, size.height/input.extent.height)
            let scaled = input.transformed(by: CGAffineTransform(scaleX: s, y: s))
            let centered = scaled.transformed(by: CGAffineTransform(translationX: (size.width-scaled.extent.width)/2, y: (size.height-scaled.extent.height)/2))
            let blurred = centered.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: composition.blur * size.width / 1080])
            if let bg = context.createCGImage(blurred, from: CGRect(origin: .zero, size: size), format: .RGBA8, colorSpace: space) { ctx.draw(bg, in: CGRect(origin: .zero, size: size)) }
        }
        let topFrame = composition.frame(image: CGSize(width: image.width, height: image.height), canvas: size)
        let frame = CGRect(x: topFrame.minX, y: size.height-topFrame.maxY, width: topFrame.width, height: topFrame.height)
        ctx.interpolationQuality = .high
        ctx.translateBy(x: frame.midX, y: frame.midY)
        ctx.rotate(by: -composition.rotationRadians)
        ctx.draw(image, in: CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height))
        return ctx.makeImage()
    }
    static func export(photo: Photo, composition: Composition, width: Int, png: Bool, destination: URL) throws {
        guard destination.resolvingSymlinksInPath() != photo.url.resolvingSymlinksInPath() else { throw CocoaError(.fileWriteNoPermission) }
        guard let image = load(photo.url, maxPixel: Int(max(photo.size.width, photo.size.height))), let rendered = render(image: image, composition: composition, size: composition.outputSize(width: width, image: photo.size)), let output = CGImageDestinationCreateWithURL(destination as CFURL, (png ? UTType.png : UTType.jpeg).identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(output, rendered, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(output) else { throw CocoaError(.fileWriteUnknown) }
    }
}

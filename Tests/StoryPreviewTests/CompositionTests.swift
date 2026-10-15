import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import StoryPreview

final class CompositionTests: XCTestCase {
    let landscape = CGSize(width: 1200, height: 600)
    let story = CGSize(width: 1080, height: 1920)
    func testStoryAndPresets() {
        var c = Composition()
        XCTAssertEqual(c.outputSize(width: 1080, image: landscape), story)
        c.preset = "Original"
        XCTAssertEqual(c.outputSize(width: 1080, image: landscape), CGSize(width: 1080, height: 540))
        c.preset = "Custom"; c.customWidth = 3; c.customHeight = 2
        XCTAssertEqual(c.outputSize(width: 1080, image: landscape).height, 720)
    }
    func testFillCoversAndClamps() {
        var c = Composition()
        c.offset = CGSize(width: 100, height: -100)
        for image in [landscape, CGSize(width: 600, height: 1200), CGSize(width: 800, height: 800)] {
            let f = c.frame(image: image, canvas: story)
            XCTAssertLessThanOrEqual(f.minX, 0.001); XCTAssertLessThanOrEqual(f.minY, 0.001)
            XCTAssertGreaterThanOrEqual(f.maxX, story.width - 0.001); XCTAssertGreaterThanOrEqual(f.maxY, story.height - 0.001)
        }
    }
    func testFitPaddingAndAspectRatio() {
        var c = Composition(); c.borders = true; c.horizontalPadding = 0.1; c.verticalPadding = 0.2
        for image in [landscape, CGSize(width: 600, height: 1200), CGSize(width: 800, height: 800)] {
            let f = c.frame(image: image, canvas: story)
            XCTAssertGreaterThanOrEqual(f.minX, 108 - 0.001); XCTAssertGreaterThanOrEqual(f.minY, 384 - 0.001)
            XCTAssertLessThanOrEqual(f.maxX, 972 + 0.001); XCTAssertLessThanOrEqual(f.maxY, 1536 + 0.001)
            XCTAssertEqual(f.width / f.height, image.width / image.height, accuracy: 0.0001)
        }
    }
    func fixture() -> CGImage {
        let ctx = CGContext(data: nil, width: 120, height: 60, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.red.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        return ctx.makeImage()!
    }
    func testExportAndOrientationAndOriginalProtection() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source.jpg")
        let dest = CGImageDestinationCreateWithURL(source as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, fixture(), [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let original = try Data(contentsOf: source)
        let photo = try XCTUnwrap(Imaging.photo(source))
        XCTAssertEqual(photo.size, CGSize(width: 60, height: 120))
        let oriented = try XCTUnwrap(Imaging.load(source, maxPixel: 120))
        XCTAssertEqual(oriented.width, 60); XCTAssertEqual(oriented.height, 120)
        for png in [true, false] {
            var c = Composition(); c.borders = true; c.blurred = !png
            let output = dir.appendingPathComponent(png ? "out.png" : "out.jpg")
            try Imaging.export(photo: photo, composition: c, width: 108, png: png, destination: output)
            let exported = try XCTUnwrap(Imaging.photo(output))
            XCTAssertEqual(exported.size, CGSize(width: 108, height: 192))
        }
        XCTAssertThrowsError(try Imaging.export(photo: photo, composition: Composition(), width: 108, png: false, destination: source))
        XCTAssertEqual(try Data(contentsOf: source), original)
    }
    func testRenderedBorders() throws {
        var c = Composition(); c.borders = true
        let rendered = try XCTUnwrap(Imaging.render(image: fixture(), composition: c, size: CGSize(width: 108, height: 192)))
        let bytes = try XCTUnwrap(rendered.dataProvider?.data) as Data
        // Opaque white background at the first pixel, red photo at canvas center.
        XCTAssertEqual(bytes[0], 255); XCTAssertEqual(bytes[1], 255); XCTAssertEqual(bytes[2], 255)
        let center = 96 * rendered.bytesPerRow + 54 * 4
        XCTAssertEqual(bytes[center], 255); XCTAssertEqual(bytes[center+1], 0); XCTAssertEqual(bytes[center+2], 0)
    }
}


extension CompositionTests {
    func testImageCacheReusesDecodedImage() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, fixture(), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let loader = ImageLoader()
        let first = await loader.load(url, maxPixel: 240)
        let second = await loader.load(url, maxPixel: 240)
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
        XCTAssertTrue(loader.cached(url, maxPixel: 240) === first)
        // File removal invalidates the fingerprint rather than serving stale pixels.
        try FileManager.default.removeItem(at: url)
        XCTAssertNil(loader.cached(url, maxPixel: 240))
    }
}

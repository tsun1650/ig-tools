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
    func testTrackpadPanInBothAxesWithBorders() {
        var c = Composition(); c.borders = true
        c.pan(by: CGSize(width: 54, height: -96), canvas: story, image: landscape)
        XCTAssertEqual(c.offset.width, 0.05, accuracy: 0.0001)
        XCTAssertEqual(c.offset.height, -0.05, accuracy: 0.0001)
        let centered = Composition().frame(image: landscape, canvas: story)
        XCTAssertTrue(centered.width > 0)
        // Normalized positioning preserves the composition when the window resizes.
        let smallFrame = c.frame(image: landscape, canvas: story)
        let largerCanvas = CGSize(width: story.width * 2, height: story.height * 2)
        let largeFrame = c.frame(image: landscape, canvas: largerCanvas)
        XCTAssertEqual(smallFrame.midX / story.width, largeFrame.midX / largerCanvas.width, accuracy: 0.0001)
        XCTAssertEqual(smallFrame.midY / story.height, largeFrame.midY / largerCanvas.height, accuracy: 0.0001)
    }
    func testTrackpadPanClampsAndReversesAtFillEdge() {
        var c = Composition(); c.zoom = 2
        c.pan(by: CGSize(width: 100000, height: 100000), canvas: story, image: landscape)
        let edge = c.frame(image: landscape, canvas: story)
        XCTAssertEqual(edge.minX, 0, accuracy: 0.0001)
        XCTAssertEqual(edge.minY, 0, accuracy: 0.0001)
        c.pan(by: CGSize(width: -10, height: -10), canvas: story, image: landscape)
        let reversed = c.frame(image: landscape, canvas: story)
        XCTAssertEqual(reversed.minX, -10, accuracy: 0.0001)
        XCTAssertEqual(reversed.minY, -10, accuracy: 0.0001)
    }
    func testTrackpadPanIgnoresInvalidCanvas() {
        var c = Composition()
        c.pan(by: CGSize(width: 30, height: 30), canvas: .zero, image: landscape)
        XCTAssertEqual(c.offset, .zero)
    }
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

extension CompositionTests {
    func testRotationWrapResetAndOriginalRatio() {
        var c = Composition(); c.preset = "Original"
        c.rotate(by: 90, image: landscape)
        XCTAssertEqual(c.outputSize(width: 1080, image: landscape), CGSize(width: 1080, height: 2160))
        c.rotate(by: -90, image: landscape)
        XCTAssertEqual(c.rotation, 0)
        c.rotate(by: 450.25, image: landscape)
        XCTAssertEqual(c.rotation, 90.25)
        c.rotate(by: .infinity, image: landscape)
        XCTAssertEqual(c.rotation, 0)
        XCTAssertEqual(Composition().rotation, 0)
    }

    func testRotatedFillCoversCornersAndFitRespectsPadding() {
        for angle in [-90.0, -31.25, 0, 45, 90, 180, 270] {
            var c = Composition(); c.rotation = angle; c.zoom = 1.5
            c.offset = CGSize(width: 100, height: -100)
            let f = c.frame(image: landscape, canvas: story)
            let cosine = cos(c.rotationRadians), sine = sin(c.rotationRadians)
            for x in [0.0, story.width] {
                for y in [0.0, story.height] {
                    let dx = x - f.midX, dy = y - f.midY
                    XCTAssertLessThanOrEqual(abs(cosine * dx + sine * dy), f.width / 2 + 0.001)
                    XCTAssertLessThanOrEqual(abs(-sine * dx + cosine * dy), f.height / 2 + 0.001)
                }
            }
            c.borders = true; c.zoom = 1; c.offset = .zero
            let fit = c.frame(image: landscape, canvas: story)
            let bounds = c.rotatedSize(image: fit.size)
            XCTAssertLessThanOrEqual(bounds.width, story.width * 0.9 + 0.001)
            XCTAssertLessThanOrEqual(bounds.height, story.height * 0.9 + 0.001)
        }
    }

    func testRotationDirectionAndExportPixels() throws {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: 120, height: 60, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.red.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        ctx.setFillColor(NSColor.blue.cgColor); ctx.fill(CGRect(x: 60, y: 0, width: 60, height: 60))
        let image = try XCTUnwrap(ctx.makeImage())
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source.png")
        let dest = CGImageDestinationCreateWithURL(source as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil); XCTAssertTrue(CGImageDestinationFinalize(dest))
        let photo = try XCTUnwrap(Imaging.photo(source))
        for angle in [-90.0, 90] {
            var c = Composition(); c.preset = "Original"; c.rotation = angle
            let preview = try XCTUnwrap(Imaging.render(image: image, composition: c, size: CGSize(width: 60, height: 120)))
            let bytes = try XCTUnwrap(preview.dataProvider?.data) as Data
            let top = 10 * preview.bytesPerRow + 30 * 4
            let bottom = 110 * preview.bytesPerRow + 30 * 4
            XCTAssertEqual(bytes[top], angle > 0 ? 255 : 0)
            XCTAssertEqual(bytes[bottom], angle > 0 ? 0 : 255)
            let output = dir.appendingPathComponent("rotated\(angle).png")
            try Imaging.export(photo: photo, composition: c, width: 60, png: true, destination: output)
            let exported = try XCTUnwrap(Imaging.load(output, maxPixel: 120))
            XCTAssertEqual(exported.width, 60); XCTAssertEqual(exported.height, 120)
            var unedited = Composition(); unedited.preset = "Original"
            let decoded = try XCTUnwrap(Imaging.render(image: exported, composition: unedited, size: CGSize(width: 60, height: 120)))
            let exportedBytes = try XCTUnwrap(decoded.dataProvider?.data) as Data
            XCTAssertEqual(exportedBytes[top], bytes[top])
            XCTAssertEqual(exportedBytes[top + 2], bytes[top + 2])
            XCTAssertEqual(exportedBytes[bottom], bytes[bottom])
            XCTAssertEqual(exportedBytes[bottom + 2], bytes[bottom + 2])
        }
    }
}

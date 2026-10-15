import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import StoryPreview

final class PhotoMetadataTests: XCTestCase {
    private var cameraProperties: [CFString: Any] {
        [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "FUJIFILM", kCGImagePropertyTIFFModel: "X-T5"],
         kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "XF35mmF1.4 R",
                                         kCGImagePropertyExifFNumber: 2.8,
                                         kCGImagePropertyExifExposureTime: 1.0 / 125,
                                         kCGImagePropertyExifISOSpeedRatings: [400],
                                         kCGImagePropertyExifFocalLength: 35,
                                         kCGImagePropertyExifFocalLenIn35mmFilm: 53,
                                         kCGImagePropertyExifExposureBiasValue: -0.33,
                                         kCGImagePropertyExifDateTimeOriginal: "2026:10:14 18:32:00",
                                         kCGImagePropertyExifOffsetTimeOriginal: "-04:00",
                                         kCGImagePropertyExifFlash: 0,
                                         kCGImagePropertyExifWhiteBalance: 0]]
    }
    func testCameraSettingsFormatting() {
        let metadata = PhotoMetadata(properties: cameraProperties)
        let values = Dictionary(uniqueKeysWithValues: metadata.fields.map { ($0.label, $0.value) })
        XCTAssertTrue(metadata.hasCameraMetadata)
        XCTAssertEqual(values["Camera"], "FUJIFILM X-T5")
        XCTAssertEqual(values["Lens"], "XF35mmF1.4 R")
        XCTAssertEqual(values["Aperture"], "f/2.8")
        XCTAssertEqual(values["Shutter"], "1/125 s")
        XCTAssertEqual(values["ISO"], "400")
        XCTAssertEqual(values["Focal length"], "35 mm")
        XCTAssertEqual(values["35mm equiv."], "53 mm")
        XCTAssertEqual(values["Exposure bias"], "-0.33 EV")
        XCTAssertEqual(values["Taken"], "2026-10-14 18:32:00 -04:00")
        XCTAssertEqual(values["Flash"], "Did not fire")
        XCTAssertEqual(values["White balance"], "Auto")
    }
    func testMissingAndInvalidTagsAndRotatedDimensions() {
        let metadata = PhotoMetadata(properties: [kCGImagePropertyPixelWidth: 600, kCGImagePropertyPixelHeight: 400, kCGImagePropertyOrientation: 6,
                                                   kCGImagePropertyExifDictionary: [kCGImagePropertyExifFNumber: -1,
                                                                                   kCGImagePropertyExifExposureTime: 0,
                                                                                   kCGImagePropertyExifISOSpeedRatings: [0, -100],
                                                                                   kCGImagePropertyExifFocalLength: Double.nan]])
        XCTAssertFalse(metadata.hasCameraMetadata)
        XCTAssertEqual(metadata.fields.count, 1)
        XCTAssertEqual(metadata.fields.first?.value, "400 × 600")
    }
    func testLongExposureAndAuxiliaryLensFallback() {
        let metadata = PhotoMetadata(properties: [kCGImagePropertyExifDictionary: [kCGImagePropertyExifExposureTime: 2.5,
                                                                                   kCGImagePropertyExifISOSpeed: 1600],
                                                   kCGImagePropertyExifAuxDictionary: [kCGImagePropertyExifAuxLensModel: "Sample lens"]])
        let values = Dictionary(uniqueKeysWithValues: metadata.fields.map { ($0.label, $0.value) })
        XCTAssertEqual(values["Shutter"], "2.5 s")
        XCTAssertEqual(values["ISO"], "1600")
        XCTAssertEqual(values["Lens"], "Sample lens")
    }
    func testReadEmbeddedExifFromJPEGWithoutChangingSource() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        let context = CGContext(data: nil, width: 120, height: 60, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(output, context.makeImage()!, cameraProperties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(output))
        let before = try Data(contentsOf: url)
        let metadata = try XCTUnwrap(PhotoMetadata.read(from: url))
        let values = Dictionary(uniqueKeysWithValues: metadata.fields.map { ($0.label, $0.value) })
        XCTAssertEqual(values["Camera"], "FUJIFILM X-T5")
        XCTAssertEqual(values["Shutter"], "1/125 s")
        XCTAssertEqual(values["ISO"], "400")
        XCTAssertEqual(values["Dimensions"], "120 × 60")
        XCTAssertNotNil(values["File size"])
        XCTAssertEqual(try Data(contentsOf: url), before)
    }
}

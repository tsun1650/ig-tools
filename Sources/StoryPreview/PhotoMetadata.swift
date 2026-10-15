import Foundation
import ImageIO
import UniformTypeIdentifiers

struct MetadataField: Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

struct PhotoMetadata {
    let fields: [MetadataField]
    let hasCameraMetadata: Bool

    static func read(from url: URL) -> PhotoMetadata? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let type = CGImageSourceGetType(source).flatMap { UTType($0 as String)?.localizedDescription }
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        return PhotoMetadata(properties: properties, format: type, fileSize: bytes)
    }

    init(properties: [CFString: Any], format: String? = nil, fileSize: Int? = nil) {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let aux = properties[kCGImagePropertyExifAuxDictionary] as? [CFString: Any] ?? [:]
        var rows: [MetadataField] = []
        func add(_ label: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(MetadataField(label: label, value: value)) }
        }
        func text(_ dictionary: [CFString: Any], _ key: CFString) -> String? {
            guard let value = dictionary[key] as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        func numeric(_ dictionary: [CFString: Any], _ key: CFString) -> Double? {
            guard let value = dictionary[key] as? NSNumber, value.doubleValue.isFinite else { return nil }
            return value.doubleValue
        }
        func combine(_ make: String?, _ model: String?) -> String? {
            guard let model else { return make }
            guard let make, !model.lowercased().hasPrefix(make.lowercased()) else { return model }
            return make + " " + model
        }
        add("Camera", combine(text(tiff, kCGImagePropertyTIFFMake), text(tiff, kCGImagePropertyTIFFModel)))
        add("Lens", combine(text(exif, kCGImagePropertyExifLensMake),
                            text(exif, kCGImagePropertyExifLensModel) ?? text(aux, kCGImagePropertyExifAuxLensModel)))
        if let aperture = numeric(exif, kCGImagePropertyExifFNumber), aperture > 0 {
            add("Aperture", "f/" + Self.number(aperture))
        }
        if let seconds = numeric(exif, kCGImagePropertyExifExposureTime), seconds > 0 {
            let reciprocal = 1 / seconds
            if reciprocal.isFinite, reciprocal >= 2, abs(reciprocal - reciprocal.rounded()) / reciprocal < 0.02 {
                add("Shutter", "1/" + Self.number(reciprocal.rounded(), digits: 0) + " s")
            } else { add("Shutter", Self.number(seconds, digits: 4) + " s") }
        }
        let ratings = (exif[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber])?.map(\.doubleValue)
            ?? (numeric(exif, kCGImagePropertyExifISOSpeedRatings) ?? numeric(exif, kCGImagePropertyExifISOSpeed)).map { [$0] } ?? []
        let iso = ratings.filter { $0.isFinite && $0 > 0 }.map { Self.number($0, digits: 0) }
        if !iso.isEmpty { add("ISO", iso.joined(separator: ", ")) }
        if let focal = numeric(exif, kCGImagePropertyExifFocalLength), focal > 0 {
            add("Focal length", Self.number(focal) + " mm")
        }
        if let focal = numeric(exif, kCGImagePropertyExifFocalLenIn35mmFilm), focal > 0 {
            add("35mm equiv.", Self.number(focal) + " mm")
        }
        if let bias = numeric(exif, kCGImagePropertyExifExposureBiasValue) {
            add("Exposure bias", (bias > 0 ? "+" : "") + Self.number(bias, digits: 2) + " EV")
        }
        if let date = text(exif, kCGImagePropertyExifDateTimeOriginal) ?? text(exif, kCGImagePropertyExifDateTimeDigitized) {
            // Preserve the camera's wall-clock time; don't invent a timezone.
            let formatted = date.count >= 10 ? date.prefix(10).replacingOccurrences(of: ":", with: "-") + date.dropFirst(10) : date
            let zone = text(exif, kCGImagePropertyExifOffsetTimeOriginal)
            add("Taken", formatted + (zone.map { " " + $0 } ?? ""))
        }
        if let flash = numeric(exif, kCGImagePropertyExifFlash), flash >= 0, flash <= 65535 {
            add("Flash", Int(flash) & 1 == 1 ? "Fired" : "Did not fire")
        }
        if let balance = numeric(exif, kCGImagePropertyExifWhiteBalance) {
            add("White balance", balance == 0 ? "Auto" : balance == 1 ? "Manual" : nil)
        }
        hasCameraMetadata = !rows.isEmpty
        if let width = numeric(properties, kCGImagePropertyPixelWidth), let height = numeric(properties, kCGImagePropertyPixelHeight), width > 0, height > 0 {
            let orientation = numeric(properties, kCGImagePropertyOrientation) ?? 1
            let rotated = (5...8).contains(orientation)
            add("Dimensions", Self.number(rotated ? height : width, digits: 0) + " × " + Self.number(rotated ? width : height, digits: 0))
        }
        add("Format", format)
        if let fileSize { add("File size", ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)) }
        add("Color profile", text(properties, kCGImagePropertyProfileName))
        fields = rows
    }

    private static func number(_ value: Double, digits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

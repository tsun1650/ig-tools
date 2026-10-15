// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "StoryPreview", platforms: [.macOS(.v14)], products: [.executable(name: "StoryPreview", targets: ["StoryPreview"])], targets: [.executableTarget(name: "StoryPreview"), .testTarget(name: "StoryPreviewTests", dependencies: ["StoryPreview"])], swiftLanguageModes: [.v5])

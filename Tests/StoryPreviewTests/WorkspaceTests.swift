import XCTest
import AppKit
@testable import StoryPreview

final class WorkspaceTests: XCTestCase {
    @MainActor
    func testNameSortPreservesSelectionEditsAndNavigation() async {
        let model = Workspace()
        let photos = ["photo1.jpg", "photo2.jpg", "photo10.jpg"].map {
            Photo(url: URL(fileURLWithPath: "/tmp/\($0)"), size: CGSize(width: 120, height: 60))
        }
        model.photos = photos
        model.selected = photos[1]
        var edit = Composition(); edit.rotation = 12.5
        model.edits[photos[1].url] = edit
        model.toggleNameSort()
        XCTAssertEqual(model.photos, photos.reversed())
        XCTAssertEqual(model.selected, photos[1])
        XCTAssertEqual(model.edits[photos[1].url]?.rotation, 12.5)
        model.move(1)
        XCTAssertEqual(model.selected, photos[0])
        model.toggleNameSort()
        XCTAssertEqual(model.photos, photos)
    }
}

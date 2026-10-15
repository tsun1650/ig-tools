import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class Workspace: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var selected: Photo?
    @Published var folder: URL?
    @Published var nameAscending = true
    @Published var editing = false
    @Published var loading = false
    @Published var exporting = false
    @Published var error: String?
    @Published var edits: [URL: Composition] = [:]
    private var thumbnailWarmup: Task<Void, Never>?
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        thumbnailWarmup?.cancel()
        folder = url; loading = true; editing = false; photos = []; selected = nil
        Task {
            do {
                let files = try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles])
                        .filter { file in
                            guard let type = try? file.resourceValues(forKeys: [.contentTypeKey]).contentType else { return false }
                            return type.conforms(to: .image) && !type.conforms(to: .rawImage)
                        }
                        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                }.value
                guard folder == url, !Task.isCancelled else { return }
                // Warm the opposite end before the first sort exposes unseen thumbnails.
                let oppositeEnd = nameAscending ? Array(files.suffix(48).reversed()) : Array(files.prefix(48))
                thumbnailWarmup = Task.detached(priority: .utility) {
                    for file in oppositeEnd {
                        guard !Task.isCancelled else { return }
                        _ = await ImageLoader.shared.load(file, maxPixel: 240, priority: .low)
                    }
                }
                // Publish small batches so the first photos appear without waiting for the folder.
                for start in stride(from: 0, to: files.count, by: 16) {
                    guard folder == url, !Task.isCancelled else { return }
                    let batch = Array(files[start..<min(start + 16, files.count)])
                    let decoded = await Task.detached(priority: .utility) { batch.compactMap(Imaging.photo) }.value
                    guard folder == url else { return }
                    // Files and batches already arrive in ascending filename order.
                    if nameAscending { photos.append(contentsOf: decoded) }
                    else { photos.insert(contentsOf: decoded.reversed(), at: 0) }
                    if selected == nil { selected = photos.first }
                    if selected != nil { loading = false }
                }
                if folder == url { loading = false }
            } catch {
                if folder == url { self.error = error.localizedDescription; loading = false }
            }
        }
    }

    func toggleNameSort() {
        nameAscending.toggle()
        photos.reverse()
    }
    func move(_ direction: Int) {
        guard !editing, let selected, let index = photos.firstIndex(of: selected), photos.indices.contains(index + direction) else { return }
        self.selected = photos[index + direction]
    }
    func binding(_ photo: Photo) -> Binding<Composition> {
        Binding(get: { self.edits[photo.url] ?? Composition() }, set: { self.edits[photo.url] = $0 })
    }
    func export(_ photo: Photo, width: Int, png: Bool) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [png ? .png : .jpeg]
        let composition = edits[photo.url] ?? Composition()
        let name = composition.preset.replacingOccurrences(of: ":", with: "x").replacingOccurrences(of: " ", with: "-")
        panel.nameFieldStringValue = "\(photo.url.deletingPathExtension().lastPathComponent)-\(name).\(png ? "png" : "jpg")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if photos.contains(where: { $0.url.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() }) {
            error = "Choose a new filename to preserve your original photo."; return
        }
        exporting = true
        Task {
            let failure = await Task.detached(priority: .userInitiated) { () -> String? in
                do { try Imaging.export(photo: photo, composition: composition, width: width, png: png, destination: url); return nil }
                catch { return error.localizedDescription }
            }.value
            exporting = false; error = failure
        }
    }
}

import SwiftUI

@main
struct StoryPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            WorkspaceView().frame(minWidth: 960, minHeight: 650)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unified)
    }
}

struct WorkspaceView: View {
    @StateObject private var model = Workspace()
    private var title: String {
        if model.editing { return model.selected?.url.lastPathComponent ?? "StoryPreview" }
        return model.folder?.lastPathComponent ?? "StoryPreview"
    }
    var body: some View {
        VStack(spacing: 0) {
            if model.folder == nil {
                welcome
            } else {
                Group {
                    if let photo = model.selected {
                        ZStack {
                            // Keep the native scroll view and split-pane sizes alive
                            // while editing, rather than recreating the gallery at the top.
                            GalleryView(model: model)
                                .opacity(model.editing ? 0 : 1)
                                .allowsHitTesting(!model.editing)
                                .accessibilityHidden(model.editing)
                            if model.editing {
                                EditorView(photo: photo, composition: model.binding(photo), model: model).id(photo.id)
                            }
                        }
                    } else if model.loading {
                        ProgressView("Reading photos…").frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView("No supported photos", systemImage: "photo", description: Text("Choose a folder containing still images. Subfolders are not scanned."))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                statusBar
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(model.folder == nil ? "" : "StoryPreview")
        .toolbar {
            if model.folder != nil && !model.editing {
                ToolbarItem(placement: .primaryAction) {
                    Button("Open Folder…", systemImage: "folder") { model.openFolder() }
                        .keyboardShortcut("o").help("Choose another photo folder")
                }
            }
        }
        .alert("Unable to complete action", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus").font(.system(size: 34, weight: .light)).foregroundStyle(.secondary).padding(.bottom, 4)
            Text("Your next frame starts here.").font(.system(size: 22, weight: .medium))
            Text("Choose a folder of photos to get started.").foregroundStyle(.secondary)
            Button("Open Folder…") { model.openFolder() }
                .buttonStyle(.borderedProminent).keyboardShortcut("o").padding(.top, 4)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if model.editing {
                    Text("Original photo preserved")
                } else if let photo = model.selected {
                    Text("\(photo.url.lastPathComponent) · \(Int(photo.size.width)) × \(Int(photo.size.height))")
                        .lineLimit(1)
                } else { Text("\(model.photos.count) photos") }
                Spacer(minLength: 12)
                if model.exporting { ProgressView().controlSize(.mini); Text("Exporting…") }
                else if model.editing { Text("Session edits") }
                else if let selected = model.selected, let index = model.photos.firstIndex(of: selected) {
                    Text("\(index + 1) of \(model.photos.count) selected")
                }
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 8)
        }.background(Color(nsColor: .windowBackgroundColor))
    }
}

struct GalleryView: View {
    @ObservedObject var model: Workspace
    @FocusState private var galleryFocused: Bool
    var body: some View {
        HSplitView {
            GeometryReader { geometry in
                let columns = max(1, Int((geometry.size.width - 24) / 150))
                VStack(spacing: 0) {
                    HStack {
                        Text(model.folder?.lastPathComponent ?? "Photos")
                        Spacer()
                        Button {
                            model.toggleNameSort()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Name")
                                Image(systemName: model.nameAscending ? "arrow.up" : "arrow.down")
                            }
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary).font(.caption)
                        .help(model.nameAscending ? "Sort by name descending" : "Sort by name ascending")
                        .accessibilityLabel("Sort by name")
                        .accessibilityValue(model.nameAscending ? "Ascending" : "Descending")
                    }.padding(.horizontal, 20).padding(.vertical, 14)
                    Divider()
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: columns), spacing: 20) {
                                ForEach(model.photos) { item in
                                    thumbnail(item).id(item.id)
                                }
                            }.padding(18)
                        }
                        .focusable().focusEffectDisabled().focused($galleryFocused)
                        .onMoveCommand { direction in
                            switch direction {
                            case .left: model.move(-1)
                            case .right: model.move(1)
                            case .up: model.move(-columns)
                            case .down: model.move(columns)
                            default: break
                            }
                        }
                        .onKeyPress(.return) { model.editing = true; return .handled }
                        .onChange(of: model.selected) { _, value in
                            if let value { proxy.scrollTo(value.id) }
                        }
                    }
                }
            }.frame(minWidth: 200, idealWidth: 500)
            if let photo = model.selected {
                VStack(spacing: 14) {
                    PhotoImage(url: photo.url, maxPixel: 2400)
                        .id(photo.id).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1).padding(.bottom, 6)
                    Text(photo.url.lastPathComponent).font(.system(size: 13, weight: .medium)).lineLimit(2).textSelection(.enabled)
                    Text("\(Int(photo.size.width)) × \(Int(photo.size.height))").font(.caption).foregroundStyle(.secondary)
                    Button("Edit Photo") { model.editing = true }.buttonStyle(.borderedProminent).padding(.top, 2)
                }.padding(24).frame(minWidth: 200, idealWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            }
        }
        .onAppear { galleryFocused = !model.editing }
        .onChange(of: model.editing) { _, editing in galleryFocused = !editing }
    }
    private func thumbnail(_ item: Photo) -> some View {
        VStack(spacing: 7) {
            PhotoImage(url: item.url, maxPixel: 240)
                .frame(maxWidth: .infinity).frame(height: 96).padding(3)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(model.selected == item ? Color.accentColor : .clear, lineWidth: 3))
            Text(item.url.lastPathComponent).font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.url.lastPathComponent)
        .accessibilityAddTraits(model.selected == item ? [.isSelected, .isButton] : .isButton)
        .onTapGesture(count: 2) { model.selected = item; model.editing = true }
        .onTapGesture { model.selected = item; galleryFocused = true }
    }
}

struct PhotoImage: View {
    let url: URL
    let maxPixel: Int
    @State private var image: CGImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFit() }
            else if failed { Label("Cannot read image", systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
            else { ProgressView() }
        }.task(id: url) {
            image = ImageLoader.shared.cached(url, maxPixel: maxPixel) ?? ImageLoader.shared.cached(url, maxPixel: 240); failed = false
            let loaded = await ImageLoader.shared.load(url, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            image = loaded; failed = loaded == nil
        }
    }
}

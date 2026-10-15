import SwiftUI

struct EditorView: View {
    let photo: Photo
    @Binding var composition: Composition
    @ObservedObject var model: Workspace
    @State private var image: CGImage?
    @State private var failed = false
    @State private var width = 1080
    @State private var png = false
    @State private var dragOrigin: CGSize?
    @State private var pinchOrigin: Double?
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let ratio = composition.ratio(image: photo.size)
                    let w = max(1, min(proxy.size.width - 64, (proxy.size.height - 64) * ratio))
                    let size = CGSize(width: w, height: w / ratio)
                    ZStack {
                        Color(nsColor: .underPageBackgroundColor)
                        if let image {
                            RenderedCanvas(image: image, composition: composition, size: size)
                                .frame(width: size.width, height: size.height)
                                .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                                .contentShape(Rectangle())
                                .gesture(DragGesture().onChanged { value in
                                    if dragOrigin == nil { dragOrigin = composition.offset }
                                    composition.offset = CGSize(width: dragOrigin!.width + value.translation.width / size.width, height: dragOrigin!.height + value.translation.height / size.height)
                                    composition.constrainOffset(image: photo.size)
                                    dragOrigin = CGSize(width: composition.offset.width - value.translation.width / size.width, height: composition.offset.height - value.translation.height / size.height)
                                }.onEnded { _ in dragOrigin = nil })
                                .simultaneousGesture(MagnificationGesture().onChanged { value in
                                    if pinchOrigin == nil { pinchOrigin = composition.zoom }
                                    composition.zoom = min(5, max(composition.borders ? 0.1 : 1, pinchOrigin! * value))
                                }.onEnded { _ in pinchOrigin = nil })
                        } else if failed { Label("This image could not be decoded.", systemImage: "exclamationmark.triangle") }
                        else { ProgressView() }
                    }
                }
                Text("Drag to position · Pinch or use the slider to zoom").font(.caption).foregroundStyle(.secondary).padding(12)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Composition").font(.system(size: 13, weight: .semibold))
                    Picker("Format", selection: $composition.preset) {
                        ForEach(Composition.presets, id: \.0) { item in Text(item.0).tag(item.0) }
                    }
                    if composition.preset == "Custom" {
                        HStack {
                            TextField("Width", value: $composition.customWidth, format: .number).onChange(of: composition.customWidth) { _, v in composition.customWidth = v.isFinite ? min(100, max(0.1, v)) : 9 }
                            Text(":")
                            TextField("Height", value: $composition.customHeight, format: .number).onChange(of: composition.customHeight) { _, v in composition.customHeight = v.isFinite ? min(100, max(0.1, v)) : 16 }
                        }
                        Text("Custom ratios are limited to 1:20–20:1.").font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Composition", selection: $composition.borders) {
                        Text("Fill").tag(false)
                        Text("Fit").tag(true)
                    }.pickerStyle(.segmented).onChange(of: composition.borders) { _, _ in composition.zoom = 1; composition.offset = .zero }
                    VStack(alignment: .leading) {
                        Text("Zoom · \(composition.zoom, specifier: "%.2f")×")
                        Slider(value: $composition.zoom, in: (composition.borders ? 0.1 : 1)...5)
                    }
                    if composition.borders {
                        Picker("Background", selection: $composition.blurred) { Text("Solid color").tag(false); Text("Blurred photo").tag(true) }
                        if composition.blurred {
                            Text("Blur strength")
                            Slider(value: $composition.blur, in: 0...80)
                        } else {
                            ColorPicker("Border color", selection: Binding(get: { Color(nsColor: composition.color) }, set: { composition.color = NSColor($0) }), supportsOpacity: false)
                        }
                        VStack(alignment: .leading) {
                            Text("Left & right padding · \(Int(composition.horizontalPadding * 100))% each")
                            Slider(value: $composition.horizontalPadding, in: 0...0.45)
                            Text("Top & bottom padding · \(Int(composition.verticalPadding * 100))% each")
                            Slider(value: $composition.verticalPadding, in: 0...0.45)
                        }
                        Button("Fit Entire Photo") { composition.zoom = 1; composition.offset = .zero }
                    }
                    Divider()
                    DisclosureGroup("Export settings") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("File type", selection: $png) {
                                Text("JPEG · High quality").tag(false)
                                Text("PNG").tag(true)
                            }
                            HStack {
                                Text("Width")
                                TextField("Pixels", value: $width, format: .number)
                                    .onChange(of: width) { _, v in width = max(64, min(4096, v)) }
                                Text("px").foregroundStyle(.secondary)
                            }
                            Text("Width: 64–4096 px. Maximum height: 8192 px.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }.padding(.top, 12)
                    }
                    let output = composition.outputSize(width: width, image: photo.size)
                    Text("\(Int(output.width)) × \(Int(output.height)) · \(png ? "PNG" : "JPEG") · sRGB")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Reset Composition") { composition = Composition() }
                        .buttonStyle(.plain).foregroundStyle(.secondary)

                }.padding(20).textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }.frame(width: 280).background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Browse", systemImage: "chevron.left") { model.editing = false }
                    .keyboardShortcut(.escape, modifiers: [])
                Button {
                    model.export(photo, width: width, png: png)
                } label: {
                    Text(model.exporting ? "Exporting…" : "Export…")
                }
                .buttonStyle(.borderedProminent)
                .disabled(image == nil || model.exporting)
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
        .onChange(of: composition.zoom) { _, _ in composition.constrainOffset(image: photo.size) }
        .onChange(of: composition.preset) { _, _ in composition.constrainOffset(image: photo.size) }
        .onChange(of: composition.customWidth) { _, _ in composition.constrainOffset(image: photo.size) }
        .onChange(of: composition.customHeight) { _, _ in composition.constrainOffset(image: photo.size) }
        .task(id: photo.id) {
            image = ImageLoader.shared.cached(photo.url, maxPixel: 2400) ?? ImageLoader.shared.cached(photo.url, maxPixel: 240)
            let result = await ImageLoader.shared.load(photo.url, maxPixel: 2400)
            guard !Task.isCancelled else { return }
            image = result; failed = result == nil
        }
    }
}

struct RenderedCanvas: View {
    let image: CGImage
    let composition: Composition
    let size: CGSize
    var body: some View {
        if let rendered = Imaging.render(image: image, composition: composition, size: CGSize(width: max(1, size.width.rounded()), height: max(1, size.height.rounded()))) {
            Image(decorative: rendered, scale: 1).resizable().interpolation(.high)
        }
    }
}

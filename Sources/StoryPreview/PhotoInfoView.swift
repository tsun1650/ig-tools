import SwiftUI

struct PhotoInfoView: View {
    let photo: Photo
    @State private var expanded = true
    @State private var metadata: PhotoMetadata?
    @State private var loading = true

    var body: some View {
        DisclosureGroup("Photo Info", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(photo.url.lastPathComponent)
                    .fontWeight(.medium).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if loading {
                    ProgressView("Reading metadata…").controlSize(.small)
                } else if let metadata {
                    ForEach(metadata.fields) { field in
                        HStack(alignment: .top, spacing: 10) {
                            Text(field.label).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                            Text(field.value).frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                    if !metadata.hasCameraMetadata {
                        Text("No camera EXIF metadata is embedded in this photo.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Could not read this file’s metadata.").foregroundStyle(.secondary)
                }
            }.padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: photo.url) {
            loading = true; metadata = nil
            let result = await Task.detached(priority: .utility) { PhotoMetadata.read(from: photo.url) }.value
            guard !Task.isCancelled else { return }
            metadata = result; loading = false
        }
    }
}

# Development

StoryPreview is a native SwiftUI and AppKit application targeting macOS 14 or later. It uses a Swift 6 package manifest with Swift 5 language mode, without third-party dependencies or runtime network services.

## Build and test

```sh
./scripts/build-app.sh
swift test
```

The build script packages `build/StoryPreview.app` and ad-hoc signs it for the current Mac architecture. Open `Package.swift` in Xcode to work on the executable scheme. Distribution signing, notarization, and a prebuilt release installer are not configured.

The Jade glass source icon lives in `Assets/IconConcepts/jade-glass.png`. The script creates standard and Retina icon sizes using `sips`, packages them with `iconutil`, and embeds `AppIcon.icns` in the bundle. Build products are ignored by Git.

## Image loading and rendering

- Folder metadata is published in batches of 16. ImageIO inspects supported still images; RAW and multi-frame images are excluded.
- Thumbnails and previews share a memory cache capped at 160 MiB. Cache keys include path, modification time, file size, and requested resolution.
- Up to three decodes run concurrently. Queued requests are cancelled when their views disappear. Small thumbnail requests can reuse embedded thumbnails; larger previews are generated from the image.
- The browser and editor share 2400-pixel previews. Exports decode the source at full resolution and use the same composition geometry as the preview.
- Photo Info reads ImageIO properties asynchronously without decoding image pixels or changing the original file.
- The gallery stays mounted behind the editor to retain its native scroll position and split-pane widths. It is hidden from hit testing, accessibility, and keyboard focus while editing.

## Composition and export

Fill mode clamps photo positioning at the edges so the canvas remains covered. Fit mode preserves the photo's aspect ratio inside the chosen horizontal and vertical margins. Trackpad panning uses AppKit scroll deltas and respects the system scrolling preference.

Default export width is 1080 pixels. Width input is limited to 64–4096 pixels; extreme custom ratios reduce it as needed to keep height within 8192 pixels. Custom ratios are limited to 1:20–20:1. JPEG exports use 0.95 quality. Both JPEG and PNG are rendered in sRGB and omit source metadata, including location.

Edits are held in memory per file and are discarded when the app closes. Persistent projects, batch export, Photos library access, and subfolder navigation are outside the current implementation.

## Validation

The test suite covers crop geometry, aspect-ratio fitting, border pixels, output dimensions, orientation, JPEG/PNG export, source preservation, cache reuse/invalidation, normalized panning and edge clamping, and EXIF reading/formatting with missing or invalid tags.

The gallery, editor, border controls, Photo Info, and scroll-position preservation have also been checked in a separate running app using sample files. For UI changes, check:

- Folder loading, selection, keyboard navigation, and pane resizing.
- Entering the editor and returning with Escape, including from far down a long folder.
- Presets, custom ratios, drag/pinch/scroll gestures, reset, and both border backgrounds.
- Exported JPEG/PNG framing against the preview, without replacing the original.
- Files without EXIF, unreadable images, and empty folders.

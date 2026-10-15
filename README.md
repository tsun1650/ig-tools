# StoryPreview

A native, local-only macOS photo browser and crop editor. Requires macOS 14 or later. No dependencies, accounts, or network services.

## Run

The built app is at `build/StoryPreview.app`. Double-click it in Finder, or run:

```sh
open build/StoryPreview.app
```

To rebuild with Xcode's Swift toolchain:

```sh
./scripts/build-app.sh
```

This creates an ad-hoc signed application for your current Mac architecture. You can also open `Package.swift` in Xcode and run the StoryPreview executable scheme. Distribution signing and notarization are not included.

## Use

1. Click **Open Folder…** (⌘O). Images in that folder appear in filename order; subfolders are not scanned.
2. Select a thumbnail to preview it. Arrow keys move between photos when the grid has keyboard focus; up/down move by a row. Press Return to edit the selected photo. Double-click a thumbnail or click **Edit Photo** to compose it.
3. Choose a crop preset or enter a custom width:height ratio. Drag the photo and pinch the trackpad, or use the zoom slider.
4. Choose **Fit** to keep the entire photo. Set a solid color or blurred-photo background. Left/right and top/bottom padding are minimum margins on each edge, expressed as percentages of the canvas. **Fit Entire Photo** restores centered fitting with those margins.
5. Expand **Export settings** to choose JPEG or PNG and the desired width, then click **Export…** in the toolbar (⇧⌘E). Save a new file. Source images in the open folder are protected from replacement.
6. Click the toolbar back arrow or press Escape to **Browse** and choose another photo. Edits are remembered per file until you quit; they are not written back to the original or saved as projects.

Supported still images are decoded using macOS ImageIO, including JPEG, PNG, HEIC, and TIFF. RAW and multi-frame images are excluded. Previews are downsampled for responsiveness; exports use the source's full resolution and honor its orientation. Exports use sRGB and omit source metadata such as location.

Default export size is 1080 pixels wide; Story produces 1080 × 1920. Width input is limited to 64–4096 pixels; extreme custom ratios reduce width as needed to keep height within 8192 pixels. The displayed dimensions are the actual export dimensions. Custom ratios are limited to 1:20–20:1.

## Validation

```sh
swift test
```

Automated tests cover fill/clamping, proportional fit and padding for landscape/portrait/square inputs, preset/custom output dimensions, oriented JPEG decoding, JPEG/PNG export, original-file preservation, rendered border pixels, and decoded-image cache reuse/invalidation.

Build and all six tests passed. The Native gallery interface was verified in the running application using generated sample photos: the welcome screen has one Open Folder action, thumbnails and the selected-photo preview load, keyboard selection works, the editor exposes border and export controls, and Escape returns to the previous selection with edits retained. Remaining manual acceptance checklist:

- Open a folder with mixed supported, unsupported, and corrupt files; check grid loading and selection.
- Navigate using arrow keys, double-click to edit, and return to the same selection.
- Exercise every preset, custom ratios, dragging, pinch zoom, sliders, reset, and both border backgrounds.
- Export JPEG and PNG and compare framing, blur, padding, and positioning against the preview.
- Navigate away and back to confirm session edits; quit and reopen to confirm they reset.

## Loading performance

The folder browser publishes metadata in batches of 16 rather than waiting for the entire folder. Non-image files are filtered before ImageIO inspection. Decoded thumbnails and previews share a memory cache capped at 160 MiB, keyed by file path, modification time, file size, and requested resolution. At most three image decodes run concurrently; queued requests are cancelled when their views disappear. Small thumbnails reuse embedded image thumbnails where available; large previews and exports are generated from the image to preserve resolution. The browser preview and editor use the same 2400-pixel cache entry. Cache contents are session-only.

## Native gallery layout

The native window toolbar shows the current folder or photo. A folder sidebar stays visible while browsing and editing. The browser places the thumbnail grid beside a selected-photo preview; editing replaces them with a crop canvas and right-hand inspector. Export settings are initially collapsed to keep composition controls prominent. There is one Open Folder action in each browsing state, and keyboard focus no longer outlines the entire workspace.

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

The packaged app uses the Jade glass icon from `Assets/IconConcepts/jade-glass.png`. The build script creates standard and Retina icon sizes with macOS `sips`, packages them with `iconutil`, and embeds `AppIcon.icns` in the app bundle. The other two icon concepts and generation prompts are retained in `Assets/IconConcepts`.

## Use

1. Click **Open Folder…** (⌘O). Images in that folder appear in filename order; subfolders are not scanned.
2. Select a thumbnail to preview it. Arrow keys move between photos when the grid has keyboard focus; up/down move by a row. Press Return to edit the selected photo. Double-click a thumbnail or click **Edit Photo** to compose it.
3. Choose a crop preset or enter a custom width:height ratio. Drag the photo or use two fingers to scroll over the editor canvas to reposition it horizontally and vertically. Pinch the trackpad or use the slider to zoom. Scrolling follows your Mac's natural-scrolling preference; scrolling over the inspector still scrolls its controls. In Fill mode, positioning stops at the image edges so no empty space appears.
4. Choose **Fit** to keep the entire photo. Set a solid color or blurred-photo background. Left/right and top/bottom padding are minimum margins on each edge, expressed as percentages of the canvas. **Fit Entire Photo** restores centered fitting with those margins.
5. Expand **Export settings** to choose JPEG or PNG and the desired width, then click **Export…** in the toolbar (⇧⌘E). Save a new file. Source images in the open folder are protected from replacement.
6. Click the toolbar back arrow or press Escape to **Browse** and choose another photo. Edits are remembered per file until you quit; they are not written back to the original or saved as projects.

Supported still images are decoded using macOS ImageIO, including JPEG, PNG, HEIC, and TIFF. RAW and multi-frame images are excluded. Previews are downsampled for responsiveness; exports use the source's full resolution and honor its orientation. Exports use sRGB and omit source metadata such as location.

Default export size is 1080 pixels wide; Story produces 1080 × 1920. Width input is limited to 64–4096 pixels; extreme custom ratios reduce width as needed to keep height within 8192 pixels. The displayed dimensions are the actual export dimensions. Custom ratios are limited to 1:20–20:1.

## Validation

```sh
swift test
```

Automated tests cover fill/clamping, proportional fit and padding for landscape/portrait/square inputs, preset/custom output dimensions, oriented JPEG decoding, JPEG/PNG export, original-file preservation, rendered border pixels, decoded-image cache reuse/invalidation, trackpad panning with normalized positioning and edge clamping, and embedded EXIF parsing/formatting with missing or invalid tags.

Build and all 13 tests passed. The Native gallery interface was verified in the running application using generated sample photos: the welcome screen has one Open Folder action, thumbnails and the selected-photo preview load, keyboard selection works, the editor exposes border and export controls, and Escape returns to the previous selection with edits retained. Remaining manual acceptance checklist:

- Open a folder with mixed supported, unsupported, and corrupt files; check grid loading and selection.
- Navigate using arrow keys, double-click to edit, and return to the same selection.
- Exercise every preset, custom ratios, dragging, pinch zoom, sliders, reset, and both border backgrounds.
- Export JPEG and PNG and compare framing, blur, padding, and positioning against the preview.
- Navigate away and back to confirm session edits; quit and reopen to confirm they reset.

## Loading performance

The folder browser publishes metadata in batches of 16 rather than waiting for the entire folder. Non-image files are filtered before ImageIO inspection. Decoded thumbnails and previews share a memory cache capped at 160 MiB, keyed by file path, modification time, file size, and requested resolution. At most three image decodes run concurrently; queued requests are cancelled when their views disappear. Small thumbnails reuse embedded image thumbnails where available; large previews and exports are generated from the image to preserve resolution. The browser preview and editor use the same 2400-pixel cache entry. Cache contents are session-only.

## Native gallery layout

The native window toolbar shows the current folder or photo. The browser places the thumbnail grid beside a selected-photo preview, without a redundant folder sidebar; drag the divider to resize the grid and preview. The grid can shrink to a single column, and the selected photo uses all available preview space. Editing replaces the grid and preview with a crop canvas and right-hand inspector. Export settings are initially collapsed to keep composition controls prominent. There is one Open Folder action in each browsing state, and keyboard focus no longer outlines the entire workspace.

Two-finger scroll routing and gallery divider resizing were verified in a separate running test app using sample photos. The test app was closed afterward; the installed app can be relaunched when current session edits are no longer needed.

## Photo Info

The editor inspector includes an expanded, collapsible **Photo Info** section. It reads metadata from the original file in the background without decoding its pixels or modifying the file. Available fields include camera, lens, aperture, shutter speed, ISO, focal length, 35mm equivalent focal length, exposure compensation, capture time and recorded timezone offset, flash, white balance, dimensions, file type, file size, and color profile. Missing tags are omitted; images without camera EXIF show a brief message. Values can be selected and copied. EXIF display was verified in the running app using a tagged JPEG fixture. Exported copies continue to omit source metadata.

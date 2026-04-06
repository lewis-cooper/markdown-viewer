# Markdown Viewer

A minimal native macOS markdown viewer and editor built with SwiftUI.

## Features

- Split view with a plain text markdown editor and live preview
- View modes for split, editor-only, and preview-only
- Native split divider with drag resize and double-click reset to 50/50
- Light and dark mode toggle in the toolbar
- Theme color customization in the standard macOS `Settings...` window
- Native file open/save, recent files, and drag-and-drop open
- Supports opening `.md` files from Finder and being set as the default Markdown app
- Unsaved changes protection on open, close, and quit
- Export to HTML or PDF
- Clickable links in the preview
- Remembers the selected theme and view mode

## Project Structure

- `Sources/MDViewer/main.swift`
  The application source, UI, document state, preview rendering, and export logic.
- `scripts/package_app.sh`
  Builds the release app bundle.
- `scripts/generate_icon.swift`
  Generates macOS icon assets from `icon/icon.png`.
- `icon/icon.png`
  Source icon used for the packaged app.
- `icon/icon.icon`
  Icon Composer source assets kept as design source.

## Requirements

- macOS 13 or newer
- Apple Swift toolchain / Command Line Tools

## Run From Source

```bash
swift run
```

If `swift run` hits a local module cache permission issue in a restricted environment, use the packaging script below instead.

## Build A Standalone App

```bash
./scripts/package_app.sh
```

This creates:

- `dist/Markdown Viewer.app`

## Install To Applications

```bash
ditto 'dist/Markdown Viewer.app' '/Applications/Markdown Viewer.app'
```

## Notes

- The preview is rendered in `WKWebView` and kept in light mode intentionally.
- The packaged app bundle is named `Markdown Viewer.app`.
- Generated build output and packaged app bundles are excluded from git via `.gitignore`.

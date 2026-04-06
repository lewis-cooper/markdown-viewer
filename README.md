# Markdown Viewer

A minimal native macOS markdown viewer and editor built with SwiftUI.

## Features

- Split view with a plain text markdown editor and live preview
- View modes for split, editor-only, and preview-only
- Theme options for light, dark, and smooth dark
- Native file open/save, recent files, and drag-and-drop open
- Unsaved changes protection on open, close, and quit
- Export to HTML or PDF
- Clickable links in the preview
- Remembers the selected theme, view mode, and optionally the last opened file

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
- Generated build output and packaged app bundles are excluded from git via `.gitignore`.

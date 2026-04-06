import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

enum WindowMetrics {
    static let minimumContentSize = CGSize(width: 680, height: 460)
    static let compactControlStripMinWidth: CGFloat = 840
    static let singleRowControlStripMinWidth: CGFloat = 1120
    static let defaultContentSize = CGSize(width: 1160, height: 700)
}

enum SplitMetrics {
    static let dividerWidth: CGFloat = 12
    static let minimumPaneWidth: CGFloat = 220
}

func clampedSplitFraction(for totalWidth: CGFloat, proposed: CGFloat) -> CGFloat {
    guard totalWidth > 0 else {
        return 0.5
    }

    let minimumFraction = SplitMetrics.minimumPaneWidth / totalWidth
    let maximumFraction = 1 - minimumFraction
    let lowerBound = min(minimumFraction, 0.5)
    let upperBound = max(maximumFraction, 0.5)
    return min(max(proposed, lowerBound), upperBound)
}

enum ThemeDefaults {
    static let lightBackgroundHex = "#FFFFFF"
    static let lightToolbarHex = "#F3F4F6"
    static let lightCardHex = "#FFFFFF"
    static let lightDividerHex = "#C7CDD6"

    static let darkBackgroundHex = "#292D3E"
    static let darkToolbarHex = "#384058"
    static let darkCardHex = "#47506B"
    static let darkDividerHex = "#D7DCE5"
}

enum ThemePreferenceKey {
    static let lightBackgroundHex = "theme.light.backgroundHex"
    static let lightToolbarHex = "theme.light.toolbarHex"
    static let lightCardHex = "theme.light.cardHex"
    static let lightDividerHex = "theme.light.dividerHex"

    static let darkBackgroundHex = "theme.dark.backgroundHex"
    static let darkToolbarHex = "theme.dark.toolbarHex"
    static let darkCardHex = "theme.dark.cardHex"
    static let darkDividerHex = "theme.dark.dividerHex"
}

enum ViewMode: String, CaseIterable, Identifiable {
    case split
    case editor
    case preview

    var id: Self { self }

    var title: String {
        switch self {
        case .split:
            return "Split"
        case .editor:
            return "Markdown"
        case .preview:
            return "Preview"
        }
    }
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: Self { self }

    var title: String {
        self == .light ? "Light" : "Dark"
    }

    var primaryTextColor: Color {
        self == .light ? Color.black.opacity(0.92) : Color.white.opacity(0.92)
    }

    var secondaryTextColor: Color {
        self == .light ? Color.black.opacity(0.62) : Color.white.opacity(0.72)
    }

    var colorScheme: ColorScheme {
        self == .light ? .light : .dark
    }

    var windowAppearanceName: NSAppearance.Name {
        self == .light ? .aqua : .darkAqua
    }

    var symbolName: String {
        self == .light ? "sun.max.fill" : "moon.fill"
    }

    static func fromStored(_ rawValue: String) -> ThemeMode {
        if rawValue == "smooth" {
            return .dark
        }

        return ThemeMode(rawValue: rawValue) ?? .light
    }
}

struct ThemePaletteConfiguration {
    let backgroundHex: String
    let toolbarHex: String
    let cardHex: String
    let dividerHex: String

    func palette(for mode: ThemeMode) -> ThemePalette {
        ThemePalette(
            mode: mode,
            background: NSColor(hexString: backgroundHex) ?? ThemePalette.defaultBackground(for: mode),
            toolbar: NSColor(hexString: toolbarHex) ?? ThemePalette.defaultToolbar(for: mode),
            card: NSColor(hexString: cardHex) ?? ThemePalette.defaultCard(for: mode),
            divider: NSColor(hexString: dividerHex) ?? ThemePalette.defaultDivider(for: mode)
        )
    }
}

struct ThemePalette {
    let mode: ThemeMode
    let background: NSColor
    let toolbar: NSColor
    let card: NSColor
    let divider: NSColor

    var backgroundColor: Color {
        Color(nsColor: background)
    }

    var stripTopColor: Color {
        Color(nsColor: toolbar.adjustingBrightness(by: mode == .light ? 0.03 : 0.04))
    }

    var stripBottomColor: Color {
        Color(nsColor: toolbar.adjustingBrightness(by: mode == .light ? -0.02 : -0.04))
    }

    var cardBackgroundColor: Color {
        Color(nsColor: card)
    }

    var cardBorderColor: Color {
        Color(nsColor: divider.withAlphaComponent(mode == .light ? 0.45 : 0.32))
    }

    var cardShadowColor: Color {
        mode == .light ? Color.black.opacity(0.06) : Color.black.opacity(0.18)
    }

    var dividerColor: Color {
        Color(nsColor: divider)
    }

    var nsBackgroundColor: NSColor {
        background
    }

    static func defaultBackground(for mode: ThemeMode) -> NSColor {
        NSColor(hexString: mode == .light ? ThemeDefaults.lightBackgroundHex : ThemeDefaults.darkBackgroundHex) ?? .white
    }

    static func defaultToolbar(for mode: ThemeMode) -> NSColor {
        NSColor(hexString: mode == .light ? ThemeDefaults.lightToolbarHex : ThemeDefaults.darkToolbarHex) ?? .white
    }

    static func defaultCard(for mode: ThemeMode) -> NSColor {
        NSColor(hexString: mode == .light ? ThemeDefaults.lightCardHex : ThemeDefaults.darkCardHex) ?? .white
    }

    static func defaultDivider(for mode: ThemeMode) -> NSColor {
        NSColor(hexString: mode == .light ? ThemeDefaults.lightDividerHex : ThemeDefaults.darkDividerHex) ?? .lightGray
    }
}

extension NSColor {
    convenience init?(hexString: String) {
        let sanitized = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6 || sanitized.count == 8 else {
            return nil
        }

        var value: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&value) else {
            return nil
        }

        let red, green, blue, alpha: CGFloat

        if sanitized.count == 8 {
            red = CGFloat((value & 0xFF00_0000) >> 24) / 255
            green = CGFloat((value & 0x00FF_0000) >> 16) / 255
            blue = CGFloat((value & 0x0000_FF00) >> 8) / 255
            alpha = CGFloat(value & 0x0000_00FF) / 255
        } else {
            red = CGFloat((value & 0xFF0000) >> 16) / 255
            green = CGFloat((value & 0x00FF00) >> 8) / 255
            blue = CGFloat(value & 0x0000FF) / 255
            alpha = 1
        }

        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var hexString: String {
        guard let color = usingColorSpace(.sRGB) else {
            return "#000000"
        }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    func adjustingBrightness(by delta: CGFloat) -> NSColor {
        guard let color = usingColorSpace(.sRGB) else {
            return self
        }

        let red = max(0, min(1, color.redComponent + delta))
        let green = max(0, min(1, color.greenComponent + delta))
        let blue = max(0, min(1, color.blueComponent + delta))
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: color.alphaComponent)
    }
}

@MainActor
final class DocumentController: ObservableObject {
    @Published var text = "" {
        didSet {
            updateDirtyState()
        }
    }
    @Published var fileURL: URL?
    @Published private(set) var recentDocumentURLs: [URL] = []
    @Published private(set) var isDirty = false

    private var savedText = ""
    private var suppressDirtyStateUpdates = false

    init() {
        refreshRecentDocuments()
    }

    var currentDocumentName: String {
        fileURL?.lastPathComponent ?? "Untitled.md"
    }

    var currentDocumentStatusText: String {
        isDirty ? "\(currentDocumentName) • Edited" : currentDocumentName
    }

    func openDocument() {
        guard confirmLossIfNeeded(for: "opening another file") else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), .plainText].compactMap { $0 }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        openDocument(at: url)
    }

    func openRecentDocument(_ url: URL) {
        guard confirmLossIfNeeded(for: "opening another file") else {
            return
        }

        openDocument(at: url)
    }

    func openDroppedDocument(_ url: URL) {
        guard confirmLossIfNeeded(for: "opening the dropped file") else {
            return
        }

        openDocument(at: url)
    }

    func clearRecentDocuments() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refreshRecentDocuments()
    }

    @discardableResult
    func saveDocument() -> Bool {
        if let url = fileURL {
            return writeDocument(to: url)
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = currentDocumentName
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), .plainText].compactMap { $0 }

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        return writeDocument(to: url)
    }

    func exportHTML() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = exportFilename(withExtension: "html")
        panel.allowedContentTypes = [.html]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try MarkdownPreview.htmlDocument(for: text).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            present(error, title: "Unable to Export HTML")
        }
    }

    func exportPDF() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = exportFilename(withExtension: "pdf")
        panel.allowedContentTypes = [.pdf]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let markdown = text

        Task {
            do {
                let data = try await PDFExporter(html: MarkdownPreview.htmlDocument(for: markdown)).export()
                try data.write(to: url)
            } catch {
                present(error, title: "Unable to Export PDF")
            }
        }
    }

    func canCloseWindow() -> Bool {
        confirmLossIfNeeded(for: "closing the window")
    }

    func canTerminateApplication() -> Bool {
        confirmLossIfNeeded(for: "quitting")
    }

    private func openDocument(at url: URL, noteAsRecent: Bool = true) {
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            applyDocumentState(text: contents, fileURL: url)

            if noteAsRecent {
                noteRecentDocument(url)
            }
        } catch {
            refreshRecentDocuments()
            present(error, title: "Unable to Open File")
        }
    }

    @discardableResult
    private func writeDocument(to url: URL) -> Bool {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            savedText = text
            isDirty = false
            fileURL = url
            noteRecentDocument(url)
            return true
        } catch {
            present(error, title: "Unable to Save File")
            return false
        }
    }

    private func exportFilename(withExtension fileExtension: String) -> String {
        let baseName = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        return "\(baseName).\(fileExtension)"
    }

    private func confirmLossIfNeeded(for action: String) -> Bool {
        guard isDirty else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to save changes before \(action)?"
        alert.informativeText = "If you don't save, your changes to \(currentDocumentName) will be lost."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveDocument()
        case .alertThirdButtonReturn:
            return true
        default:
            return false
        }
    }

    private func applyDocumentState(text: String, fileURL: URL?) {
        suppressDirtyStateUpdates = true
        savedText = text
        self.text = text
        self.fileURL = fileURL
        isDirty = false
        suppressDirtyStateUpdates = false
    }

    private func updateDirtyState() {
        guard !suppressDirtyStateUpdates else {
            return
        }

        isDirty = text != savedText
    }

    private func noteRecentDocument(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refreshRecentDocuments()
    }

    private func refreshRecentDocuments() {
        recentDocumentURLs = NSDocumentController.shared.recentDocumentURLs.filter(\.isFileURL)
    }

    private func present(_ error: Error, title: String) {
        let alert = NSAlert(error: error)
        alert.messageText = title
        alert.runModal()
    }
}

struct ContentView: View {
    private enum ControlStripLayoutMode {
        case wide
        case medium
        case compact
    }

    @EnvironmentObject private var document: DocumentController
    @AppStorage("viewMode") private var viewModeRawValue = ViewMode.split.rawValue
    @AppStorage("themeMode") private var themeModeRawValue = ThemeMode.light.rawValue
    @AppStorage(ThemePreferenceKey.lightBackgroundHex) private var lightBackgroundHex = ThemeDefaults.lightBackgroundHex
    @AppStorage(ThemePreferenceKey.lightToolbarHex) private var lightToolbarHex = ThemeDefaults.lightToolbarHex
    @AppStorage(ThemePreferenceKey.lightCardHex) private var lightCardHex = ThemeDefaults.lightCardHex
    @AppStorage(ThemePreferenceKey.lightDividerHex) private var lightDividerHex = ThemeDefaults.lightDividerHex
    @AppStorage(ThemePreferenceKey.darkBackgroundHex) private var darkBackgroundHex = ThemeDefaults.darkBackgroundHex
    @AppStorage(ThemePreferenceKey.darkToolbarHex) private var darkToolbarHex = ThemeDefaults.darkToolbarHex
    @AppStorage(ThemePreferenceKey.darkCardHex) private var darkCardHex = ThemeDefaults.darkCardHex
    @AppStorage(ThemePreferenceKey.darkDividerHex) private var darkDividerHex = ThemeDefaults.darkDividerHex
    @State private var isDropTargeted = false
    @State private var controlStripWidth: CGFloat = 0
    @State private var splitFraction: CGFloat = 0.5

    private var viewMode: ViewMode {
        ViewMode(rawValue: viewModeRawValue) ?? .split
    }

    private var themeMode: ThemeMode {
        if let forcedTheme = ProcessInfo.processInfo.environment["MDVIEWER_FORCE_THEME"] {
            return ThemeMode(rawValue: forcedTheme) ?? ThemeMode.fromStored(themeModeRawValue)
        }

        return ThemeMode.fromStored(themeModeRawValue)
    }

    private var lightThemeConfiguration: ThemePaletteConfiguration {
        ThemePaletteConfiguration(
            backgroundHex: lightBackgroundHex,
            toolbarHex: lightToolbarHex,
            cardHex: lightCardHex,
            dividerHex: lightDividerHex
        )
    }

    private var darkThemeConfiguration: ThemePaletteConfiguration {
        ThemePaletteConfiguration(
            backgroundHex: darkBackgroundHex,
            toolbarHex: darkToolbarHex,
            cardHex: darkCardHex,
            dividerHex: darkDividerHex
        )
    }

    private var themePalette: ThemePalette {
        switch themeMode {
        case .light:
            return lightThemeConfiguration.palette(for: .light)
        case .dark:
            return darkThemeConfiguration.palette(for: .dark)
        }
    }

    private var viewModeBinding: Binding<ViewMode> {
        Binding(
            get: { viewMode },
            set: { viewModeRawValue = $0.rawValue }
        )
    }

    private var isDarkModeBinding: Binding<Bool> {
        Binding(
            get: { themeMode == .dark },
            set: { themeModeRawValue = $0 ? ThemeMode.dark.rawValue : ThemeMode.light.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            controlStrip
            Rectangle()
                .fill(themePalette.dividerColor)
                .frame(height: 1)

            Group {
                switch viewMode {
                case .split:
                    splitPane
                case .editor:
                    editorPane
                case .preview:
                    previewPane
                }
            }
        }
        .background(themePalette.backgroundColor)
        .background(WindowConfigurationView(themeMode: themeMode, themePalette: themePalette, document: document))
        .frame(
            minWidth: WindowMetrics.minimumContentSize.width,
            minHeight: WindowMetrics.minimumContentSize.height
        )
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleFileDrop)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 3, dash: [8, 8]))
                    .foregroundStyle(themeMode.primaryTextColor.opacity(0.45))
                    .padding(12)
            }
        }
    }

    private var splitPane: some View {
        NativeSplitPane(
            splitFraction: $splitFraction,
            dividerNSColor: themePalette.divider,
            isLightMode: themeMode == .light,
            leading: editorPane,
            trailing: previewPane
        )
    }

    private var controlStripLayoutMode: ControlStripLayoutMode {
        if controlStripWidth >= WindowMetrics.singleRowControlStripMinWidth {
            return .wide
        }

        if controlStripWidth >= WindowMetrics.compactControlStripMinWidth {
            return .medium
        }

        return .compact
    }

    private var controlStrip: some View {
        Group {
            switch controlStripLayoutMode {
            case .wide:
                singleRowControlStrip
            case .medium:
                stackedControlStrip
            case .compact:
                compactControlStrip
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [themePalette.stripTopColor, themePalette.stripBottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(controlStripWidthReader)
        .environment(\.colorScheme, themeMode.colorScheme)
    }

    private var singleRowControlStrip: some View {
        HStack(spacing: 12) {
            fileToolbarCard
            layoutToolbarCard
            themeToolbarCard
            Spacer(minLength: 12)
            documentStatusCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stackedControlStrip: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                fileToolbarCard
                Spacer(minLength: 12)
                documentStatusCard
            }

            HStack(spacing: 12) {
                layoutToolbarCard
                Spacer(minLength: 12)
                themeToolbarCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactControlStrip: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                compactFileToolbarCard
                Spacer(minLength: 10)
                compactDocumentStatusCard
            }

            HStack(spacing: 10) {
                compactLayoutToolbarCard
                Spacer(minLength: 10)
                compactThemeToolbarCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlStripWidthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    controlStripWidth = proxy.size.width
                }
                .onChange(of: proxy.size.width) { newValue in
                    controlStripWidth = newValue
                }
        }
    }

    private var fileToolbarCard: some View {
        toolbarCard {
            HStack(spacing: 10) {
                toolbarSectionLabel(title: "File", symbol: "folder")
                stripDivider
                fileActionStrip
            }
        }
    }

    private var compactFileToolbarCard: some View {
        toolbarCard(horizontalPadding: 8, verticalPadding: 7, shadowRadius: 5) {
            fileActionStrip
        }
    }

    private var layoutToolbarCard: some View {
        toolbarCard {
            HStack(spacing: 10) {
                toolbarSectionLabel(title: "Layout", symbol: "rectangle.split.2x1")
                stripDivider
                viewModeStrip
            }
        }
    }

    private var compactLayoutToolbarCard: some View {
        toolbarCard(horizontalPadding: 8, verticalPadding: 7, shadowRadius: 5) {
            viewModeStrip
        }
    }

    private var themeToolbarCard: some View {
        toolbarCard {
            HStack(spacing: 10) {
                toolbarSectionLabel(title: "Theme", symbol: themeMode.symbolName)
                stripDivider
                modeToggleStrip
            }
        }
    }

    private var compactThemeToolbarCard: some View {
        toolbarCard(horizontalPadding: 8, verticalPadding: 7, shadowRadius: 5) {
            HStack(spacing: 7) {
                Image(systemName: themeMode.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeMode.secondaryTextColor)

                modeToggleStrip
            }
        }
    }

    private var fileActionStrip: some View {
        HStack(spacing: 6) {
            Button(action: document.openDocument) {
                Label("Open", systemImage: "folder")
            }
            .lineLimit(1)

            Button(action: { _ = document.saveDocument() }) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .lineLimit(1)

            Menu {
                if document.recentDocumentURLs.isEmpty {
                    Button("No Recent Documents") {}
                        .disabled(true)
                } else {
                    ForEach(document.recentDocumentURLs, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            document.openRecentDocument(url)
                        }
                    }

                    Divider()

                    Button("Clear Menu", action: document.clearRecentDocuments)
                }
            } label: {
                Label("Recent", systemImage: "clock.arrow.circlepath")
            }
            .lineLimit(1)

            Menu {
                Button("HTML...", action: document.exportHTML)
                Button("PDF...", action: document.exportPDF)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        .buttonStyle(.bordered)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var viewModeStrip: some View {
        Picker("View", selection: viewModeBinding) {
            ForEach(ViewMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 240)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var modeToggleStrip: some View {
        HStack(spacing: 8) {
            Text(themeMode.title)
                .font(.system(size: 12, weight: .semibold))

            Toggle(isOn: isDarkModeBinding) {
                EmptyView()
            }
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var documentStatusCard: some View {
        ViewThatFits(in: .horizontal) {
            toolbarCard {
                HStack(spacing: 10) {
                    statusIndicator

                    VStack(alignment: .leading, spacing: 1) {
                        Text(document.currentDocumentName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text(document.isDirty ? "Edited locally" : "Saved")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(document.isDirty ? Color.orange : themeMode.secondaryTextColor)
                    }
                }
            }

            toolbarCard {
                HStack(spacing: 8) {
                    statusIndicator
                    Text(document.currentDocumentStatusText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(themeMode.secondaryTextColor)
                }
            }

            toolbarCard {
                HStack(spacing: 8) {
                    statusIndicator
                    Text(document.currentDocumentName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(themeMode.secondaryTextColor)
                }
            }

            toolbarCard {
                statusIndicatorOnly
            }
        }
        .frame(maxWidth: 260, alignment: .trailing)
    }

    private var compactDocumentStatusCard: some View {
        ViewThatFits(in: .horizontal) {
            toolbarCard(horizontalPadding: 8, verticalPadding: 7, shadowRadius: 5) {
                HStack(spacing: 8) {
                    statusIndicator
                    Text(document.currentDocumentName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            toolbarCard(horizontalPadding: 8, verticalPadding: 7, shadowRadius: 5) {
                statusIndicatorOnly
            }
        }
        .frame(maxWidth: 190, alignment: .trailing)
    }

    private var stripDivider: some View {
        Rectangle()
            .fill(themePalette.dividerColor.opacity(themeMode == .light ? 0.75 : 0.55))
            .frame(width: 1, height: 16)
    }

    private var statusIndicatorOnly: some View {
        statusIndicator
            .padding(.horizontal, 2)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(document.isDirty ? Color.orange : themeMode.secondaryTextColor.opacity(0.45))
            .frame(width: 7, height: 7)
    }

    private func toolbarSectionLabel(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))

            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
        }
        .foregroundStyle(themeMode.secondaryTextColor)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func toolbarCard<Content: View>(
        horizontalPadding: CGFloat = 10,
        verticalPadding: CGFloat = 8,
        shadowRadius: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(themePalette.cardBackgroundColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(themePalette.cardBorderColor, lineWidth: 1)
            }
            .shadow(color: themePalette.cardShadowColor, radius: shadowRadius, y: 1)
    }

    private var editorPane: some View {
        ZStack {
            themePalette.backgroundColor

            TextEditor(text: $document.text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .foregroundStyle(themeMode.primaryTextColor)
                .background(themePalette.backgroundColor)
        }
        .environment(\.colorScheme, themeMode.colorScheme)
        .frame(minWidth: 220, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewPane: some View {
        ZStack {
            Color.white
            MarkdownPreview(markdown: document.text)
        }
        .frame(minWidth: 220, maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
            guard let data, let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? else {
                return
            }

            Task { @MainActor in
                document.openDroppedDocument(url)
            }
        }

        return true
    }
}

struct NativeSplitPane<Leading: View, Trailing: View>: NSViewRepresentable {
    @Binding var splitFraction: CGFloat
    let dividerNSColor: NSColor
    let isLightMode: Bool
    let leading: Leading
    let trailing: Trailing

    func makeCoordinator() -> Coordinator {
        Coordinator(splitFraction: $splitFraction)
    }

    func makeNSView(context: Context) -> SplitContainerView {
        let containerView = SplitContainerView()
        containerView.splitView.delegate = context.coordinator
        containerView.splitView.themeDividerColor = dividerNSColor
        containerView.splitView.isLightMode = isLightMode
        containerView.splitView.onResetToCenter = { [weak containerView, weak coordinator = context.coordinator] in
            guard let containerView, let coordinator else {
                return
            }

            coordinator.resetSplitToCenter(in: containerView)
        }
        containerView.leadingHostingView.rootView = AnyView(leading)
        containerView.trailingHostingView.rootView = AnyView(trailing)

        DispatchQueue.main.async {
            context.coordinator.applySplitFractionIfNeeded(in: containerView, fraction: splitFraction, force: true)
        }

        return containerView
    }

    func updateNSView(_ nsView: SplitContainerView, context: Context) {
        nsView.splitView.themeDividerColor = dividerNSColor
        nsView.splitView.isLightMode = isLightMode
        nsView.leadingHostingView.rootView = AnyView(leading)
        nsView.trailingHostingView.rootView = AnyView(trailing)

        DispatchQueue.main.async {
            context.coordinator.applySplitFractionIfNeeded(in: nsView, fraction: splitFraction)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSSplitViewDelegate {
        private var splitFraction: Binding<CGFloat>
        private var isApplyingProgrammaticUpdate = false
        private var hasAppliedInitialSplit = false

        init(splitFraction: Binding<CGFloat>) {
            self.splitFraction = splitFraction
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainSplitPosition proposedPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let totalWidth = max(splitView.bounds.width - splitView.dividerThickness, 1)
            let clampedFraction = clampedSplitFraction(for: totalWidth, proposed: proposedPosition / totalWidth)
            return totalWidth * clampedFraction
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard
                let splitView = notification.object as? NSSplitView,
                let containerView = splitView.superview as? SplitContainerView
            else {
                return
            }

            if !hasAppliedInitialSplit {
                applySplitFractionIfNeeded(in: containerView, fraction: splitFraction.wrappedValue, force: true)
                return
            }

            guard
                !isApplyingProgrammaticUpdate,
                let leadingWidth = splitView.subviews.first?.frame.width
            else {
                return
            }

            let totalWidth = max(splitView.bounds.width - splitView.dividerThickness, 1)
            let nextFraction = clampedSplitFraction(for: totalWidth, proposed: leadingWidth / totalWidth)
            (splitView as? ThemedSplitView)?.desiredFraction = nextFraction

            if abs(splitFraction.wrappedValue - nextFraction) > 0.001 {
                splitFraction.wrappedValue = nextFraction
            }
        }

        func applySplitFractionIfNeeded(in containerView: SplitContainerView, fraction: CGFloat, force: Bool = false) {
            let splitView = containerView.splitView
            splitView.layoutSubtreeIfNeeded()

            let totalWidth = max(splitView.bounds.width - splitView.dividerThickness, 1)
            guard totalWidth > 1 else {
                return
            }

            let clampedFraction = clampedSplitFraction(for: totalWidth, proposed: fraction)
            let targetLeadingWidth = totalWidth * clampedFraction
            let currentLeadingWidth = splitView.subviews.first?.frame.width ?? 0
            hasAppliedInitialSplit = true
            splitView.desiredFraction = clampedFraction

            guard force || abs(currentLeadingWidth - targetLeadingWidth) > 1 else {
                return
            }

            isApplyingProgrammaticUpdate = true
            splitView.setPosition(targetLeadingWidth, ofDividerAt: 0)
            isApplyingProgrammaticUpdate = false
        }

        func resetSplitToCenter(in containerView: SplitContainerView) {
            splitFraction.wrappedValue = 0.5
            applySplitFractionIfNeeded(in: containerView, fraction: 0.5, force: true)
        }
    }
}

final class SplitContainerView: NSView {
    let splitView = ThemedSplitView()
    let leadingHostingView = NSHostingView(rootView: AnyView(EmptyView()))
    let trailingHostingView = NSHostingView(rootView: AnyView(EmptyView()))

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        splitView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.topAnchor.constraint(equalTo: topAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addSubview(leadingHostingView)
        splitView.addSubview(trailingHostingView)
        splitView.adjustSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ThemedSplitView: NSSplitView {
    var themeDividerColor: NSColor = .separatorColor {
        didSet {
            needsDisplay = true
        }
    }

    var isLightMode = true {
        didSet {
            needsDisplay = true
        }
    }

    var desiredFraction: CGFloat = 0.5
    var onResetToCenter: (() -> Void)?

    override var dividerThickness: CGFloat {
        SplitMetrics.dividerWidth
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        guard subviews.count == 2 else {
            super.resizeSubviews(withOldSize: oldSize)
            return
        }

        let totalWidth = max(bounds.width - dividerThickness, 1)
        let fraction = clampedSplitFraction(for: totalWidth, proposed: desiredFraction)
        let leadingWidth = totalWidth * fraction
        let trailingWidth = max(totalWidth - leadingWidth, 0)

        subviews[0].frame = NSRect(
            x: 0,
            y: 0,
            width: leadingWidth,
            height: bounds.height
        )
        subviews[1].frame = NSRect(
            x: leadingWidth + dividerThickness,
            y: 0,
            width: trailingWidth,
            height: bounds.height
        )
    }

    override func drawDivider(in rect: NSRect) {
        let backgroundColor = themeDividerColor.withAlphaComponent(isLightMode ? 0.14 : 0.18)
        backgroundColor.setFill()
        rect.fill()

        let lineRect = NSRect(
            x: rect.midX - 0.5,
            y: rect.minY,
            width: 1,
            height: rect.height
        )
        themeDividerColor.setFill()
        lineRect.fill()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let location = convert(event.locationInWindow, from: nil)
            let dividerRect = activeDividerRect()

            if dividerRect.contains(location) {
                onResetToCenter?()
                return
            }
        }

        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        let dividerRect = activeDividerRect()
        guard !dividerRect.isEmpty else {
            return
        }

        addCursorRect(dividerRect, cursor: .resizeLeftRight)
    }

    private func activeDividerRect() -> NSRect {
        guard subviews.count > 1 else {
            return .zero
        }

        return NSRect(
            x: subviews[0].frame.maxX,
            y: bounds.minY,
            width: dividerThickness,
            height: bounds.height
        )
    }
}

struct WindowConfigurationView: NSViewRepresentable {
    let themeMode: ThemeMode
    let themePalette: ThemePalette
    let document: DocumentController

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            context.coordinator.configureWindow(for: view, themeMode: themeMode, themePalette: themePalette)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.document = document

        DispatchQueue.main.async {
            context.coordinator.configureWindow(for: nsView, themeMode: themeMode, themePalette: themePalette)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        var document: DocumentController
        weak var window: NSWindow?
        private var hasAppliedInitialSize = false

        init(document: DocumentController) {
            self.document = document
        }

        func configureWindow(for view: NSView, themeMode: ThemeMode, themePalette: ThemePalette) {
            guard let window = view.window else {
                return
            }

            if self.window !== window || window.delegate !== self {
                window.delegate = self
                self.window = window
            }

            window.appearance = NSAppearance(named: themeMode.windowAppearanceName)
            window.backgroundColor = themePalette.nsBackgroundColor
            window.title = document.currentDocumentName
            window.representedURL = document.fileURL
            window.isDocumentEdited = document.isDirty
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.contentMinSize = NSSize(
                width: WindowMetrics.minimumContentSize.width,
                height: WindowMetrics.minimumContentSize.height
            )

            if !hasAppliedInitialSize {
                window.setContentSize(NSSize(
                    width: WindowMetrics.defaultContentSize.width,
                    height: WindowMetrics.defaultContentSize.height
                ))
                window.center()
                hasAppliedInitialSize = true
            }

            LayoutVerificationRunner.shared.scheduleIfNeeded(window: window)
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            document.canCloseWindow()
        }
    }
}

struct MarkdownPreview: NSViewRepresentable {
    let markdown: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        webView.appearance = NSAppearance(named: .aqua)
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(Self.htmlDocument(for: ""), baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let script = "window.renderMarkdown(\(Self.javaScriptLiteral(for: markdown)));"

        webView.appearance = NSAppearance(named: .aqua)

        if context.coordinator.isLoaded {
            webView.evaluateJavaScript(script)
        } else {
            context.coordinator.pendingScript = script
        }
    }

    static func htmlDocument(for markdown: String) -> String {
        htmlShell.replacingOccurrences(
            of: "__INITIAL_RENDER__",
            with: "window.renderMarkdown(\(javaScriptLiteral(for: markdown)));"
        )
    }

    static func javaScriptLiteral(for value: String) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: [value]),
            let string = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }

        return String(string.dropFirst().dropLast())
    }

    static let htmlShell = #"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        :root {
          color-scheme: light;
        }

        html, body {
          min-height: 100%;
          background: #ffffff;
          color: #1f1f1f;
        }

        body {
          margin: 0;
          padding: 18px;
          font: 14px/1.55 -apple-system, BlinkMacSystemFont, sans-serif;
          overflow-wrap: break-word;
        }

        h1, h2, h3, h4, h5, h6 {
          line-height: 1.25;
          margin: 1.2em 0 0.5em;
        }

        p, ul, ol, pre, blockquote {
          margin: 0 0 1em;
        }

        code, pre {
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        }

        pre {
          padding: 12px;
          border-radius: 8px;
          background: #f3f4f6;
          overflow-x: auto;
        }

        code {
          background: #f3f4f6;
          padding: 0.1em 0.3em;
          border-radius: 4px;
        }

        blockquote {
          padding-left: 12px;
          border-left: 3px solid #c7c7cc;
          color: #4b5563;
        }

        a {
          color: #0a84ff;
          text-decoration: none;
        }

        a:hover {
          text-decoration: underline;
        }
      </style>
    </head>
    <body>
      <div id="preview"></div>
      <script>
        function escapeHtml(value) {
          return value
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;");
        }

        function applyInline(text) {
          let html = escapeHtml(text);

          html = html.replace(/`([^`]+)`/g, "<code>$1</code>");
          html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
          html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
          html = html.replace(/__([^_]+)__/g, "<strong>$1</strong>");
          html = html.replace(/(^|[\\s(])\*([^*]+)\*(?=$|[\\s).,!?:;])/g, "$1<em>$2</em>");
          html = html.replace(/(^|[\\s(])_([^_]+)_(?=$|[\\s).,!?:;])/g, "$1<em>$2</em>");

          return html;
        }

        function parseMarkdown(markdown) {
          const lines = markdown.replace(/\r\n?/g, "\n").split("\n");
          const html = [];
          let paragraph = [];
          let inCodeBlock = false;
          let inList = false;
          let listType = "ul";

          function flushParagraph() {
            if (!paragraph.length) return;
            html.push("<p>" + applyInline(paragraph.join(" ")) + "</p>");
            paragraph = [];
          }

          function closeList() {
            if (!inList) return;
            html.push("</" + listType + ">");
            inList = false;
          }

          for (const rawLine of lines) {
            const line = rawLine.trimEnd();

            if (line.startsWith("```")) {
              flushParagraph();
              closeList();

              if (inCodeBlock) {
                html.push("</code></pre>");
              } else {
                html.push("<pre><code>");
              }

              inCodeBlock = !inCodeBlock;
              continue;
            }

            if (inCodeBlock) {
              html.push(escapeHtml(rawLine) + "\n");
              continue;
            }

            if (!line) {
              flushParagraph();
              closeList();
              continue;
            }

            const headingMatch = line.match(/^(#{1,6})\s+(.*)$/);
            if (headingMatch) {
              flushParagraph();
              closeList();

              const level = headingMatch[1].length;
              html.push("<h" + level + ">" + applyInline(headingMatch[2]) + "</h" + level + ">");
              continue;
            }

            const blockquoteMatch = line.match(/^>\s?(.*)$/);
            if (blockquoteMatch) {
              flushParagraph();
              closeList();
              html.push("<blockquote><p>" + applyInline(blockquoteMatch[1]) + "</p></blockquote>");
              continue;
            }

            const unorderedMatch = line.match(/^[-*+]\s+(.*)$/);
            const orderedMatch = line.match(/^\d+\.\s+(.*)$/);

            if (unorderedMatch || orderedMatch) {
              flushParagraph();
              const nextType = orderedMatch ? "ol" : "ul";

              if (!inList || listType !== nextType) {
                closeList();
                listType = nextType;
                html.push("<" + listType + ">");
                inList = true;
              }

              html.push("<li>" + applyInline((unorderedMatch || orderedMatch)[1]) + "</li>");
              continue;
            }

            paragraph.push(line.trim());
          }

          flushParagraph();
          closeList();

          if (inCodeBlock) {
            html.push("</code></pre>");
          }

          return html.join("\n");
        }

        window.renderMarkdown = function(markdown) {
          document.getElementById("preview").innerHTML = parseMarkdown(markdown);
        };

        __INITIAL_RENDER__
      </script>
    </body>
    </html>
    """#

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var isLoaded = false
        var pendingScript = "window.renderMarkdown(\"\");"

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            webView.evaluateJavaScript(pendingScript)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}

@MainActor
final class PDFExporter: NSObject, WKNavigationDelegate {
    private let html: String
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Data, Error>?

    init(html: String) {
        self.html = html
    }

    func export() async throws -> Data {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1200), configuration: configuration)
        webView.appearance = NSAppearance(named: .aqua)
        webView.navigationDelegate = self
        self.webView = webView

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)") { [weak self] result, error in
            guard let self else {
                return
            }

            if let error {
                self.finish(with: error)
                return
            }

            let height = max((result as? NSNumber)?.doubleValue ?? 1200, 1200)
            let configuration = WKPDFConfiguration()
            configuration.rect = CGRect(x: 0, y: 0, width: webView.bounds.width, height: height)

            webView.createPDF(configuration: configuration) { result in
                switch result {
                case .success(let data):
                    self.finish(with: data)
                case .failure(let error):
                    self.finish(with: error)
                }
            }
        }
    }

    private func finish(with data: Data) {
        continuation?.resume(returning: data)
        cleanup()
    }

    private func finish(with error: Error) {
        continuation?.resume(throwing: error)
        cleanup()
    }

    private func cleanup() {
        continuation = nil
        webView?.navigationDelegate = nil
        webView = nil
    }
}

struct ThemeSettingsView: View {
    @AppStorage(ThemePreferenceKey.lightBackgroundHex) private var lightBackgroundHex = ThemeDefaults.lightBackgroundHex
    @AppStorage(ThemePreferenceKey.lightToolbarHex) private var lightToolbarHex = ThemeDefaults.lightToolbarHex
    @AppStorage(ThemePreferenceKey.lightCardHex) private var lightCardHex = ThemeDefaults.lightCardHex
    @AppStorage(ThemePreferenceKey.lightDividerHex) private var lightDividerHex = ThemeDefaults.lightDividerHex
    @AppStorage(ThemePreferenceKey.darkBackgroundHex) private var darkBackgroundHex = ThemeDefaults.darkBackgroundHex
    @AppStorage(ThemePreferenceKey.darkToolbarHex) private var darkToolbarHex = ThemeDefaults.darkToolbarHex
    @AppStorage(ThemePreferenceKey.darkCardHex) private var darkCardHex = ThemeDefaults.darkCardHex
    @AppStorage(ThemePreferenceKey.darkDividerHex) private var darkDividerHex = ThemeDefaults.darkDividerHex

    var body: some View {
        Form {
            Section {
                Text("Use the toolbar switch to toggle between Light and Dark. Customize the palette for each mode here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Light Theme") {
                ColorPicker("Window Background", selection: colorBinding(for: $lightBackgroundHex, fallback: ThemeDefaults.lightBackgroundHex), supportsOpacity: false)
                ColorPicker("Toolbar", selection: colorBinding(for: $lightToolbarHex, fallback: ThemeDefaults.lightToolbarHex), supportsOpacity: false)
                ColorPicker("Cards", selection: colorBinding(for: $lightCardHex, fallback: ThemeDefaults.lightCardHex), supportsOpacity: false)
                ColorPicker("Divider", selection: colorBinding(for: $lightDividerHex, fallback: ThemeDefaults.lightDividerHex), supportsOpacity: false)

                Button("Reset Light Theme") {
                    lightBackgroundHex = ThemeDefaults.lightBackgroundHex
                    lightToolbarHex = ThemeDefaults.lightToolbarHex
                    lightCardHex = ThemeDefaults.lightCardHex
                    lightDividerHex = ThemeDefaults.lightDividerHex
                }
            }

            Section("Dark Theme") {
                ColorPicker("Window Background", selection: colorBinding(for: $darkBackgroundHex, fallback: ThemeDefaults.darkBackgroundHex), supportsOpacity: false)
                ColorPicker("Toolbar", selection: colorBinding(for: $darkToolbarHex, fallback: ThemeDefaults.darkToolbarHex), supportsOpacity: false)
                ColorPicker("Cards", selection: colorBinding(for: $darkCardHex, fallback: ThemeDefaults.darkCardHex), supportsOpacity: false)
                ColorPicker("Divider", selection: colorBinding(for: $darkDividerHex, fallback: ThemeDefaults.darkDividerHex), supportsOpacity: false)

                Button("Reset Dark Theme") {
                    darkBackgroundHex = ThemeDefaults.darkBackgroundHex
                    darkToolbarHex = ThemeDefaults.darkToolbarHex
                    darkCardHex = ThemeDefaults.darkCardHex
                    darkDividerHex = ThemeDefaults.darkDividerHex
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 430)
    }

    private func colorBinding(for hex: Binding<String>, fallback: String) -> Binding<Color> {
        Binding(
            get: {
                Color(nsColor: NSColor(hexString: hex.wrappedValue) ?? NSColor(hexString: fallback) ?? .white)
            },
            set: { newColor in
                hex.wrappedValue = NSColor(newColor).hexString
            }
        )
    }
}

struct AppCommands: Commands {
    @ObservedObject var document: DocumentController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open...", action: document.openDocument)
                .keyboardShortcut("o")

            Menu("Open Recent") {
                if document.recentDocumentURLs.isEmpty {
                    Button("No Recent Documents") {}
                        .disabled(true)
                } else {
                    ForEach(document.recentDocumentURLs, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            document.openRecentDocument(url)
                        }
                    }

                    Divider()

                    Button("Clear Menu", action: document.clearRecentDocuments)
                }
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save", action: { _ = document.saveDocument() })
                .keyboardShortcut("s")
        }

        CommandGroup(after: .saveItem) {
            Divider()

            Button("Export HTML...", action: document.exportHTML)
            Button("Export PDF...", action: document.exportPDF)
        }
    }
}

@MainActor
final class LayoutVerificationRunner {
    static let shared = LayoutVerificationRunner()

    private struct LayoutSnapshot {
        let widths: [String: CGFloat]
        let overflow: [String: CGFloat]
    }

    private let isEnabled = ProcessInfo.processInfo.environment["MDVIEWER_VERIFY_TOPBAR_RESIZE"] == "1"
    private var hasStarted = false

    func scheduleIfNeeded(window: NSWindow) {
        guard isEnabled, !hasStarted else {
            return
        }

        hasStarted = true
        let minimumWidth = max(window.contentMinSize.width, WindowMetrics.minimumContentSize.width)
        let mediumWidth = (WindowMetrics.compactControlStripMinWidth + WindowMetrics.singleRowControlStripMinWidth) / 2

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.measure(window: window, width: minimumWidth, label: "minimum") { minimumSnapshot in
                self.measure(window: window, width: mediumWidth, label: "medium") { mediumSnapshot in
                    self.measure(window: window, width: 1500, label: "wide") { wideSnapshot in
                        self.finish(window: window, minimum: minimumSnapshot, medium: mediumSnapshot, wide: wideSnapshot)
                    }
                }
            }
        }
    }

    private func measure(
        window: NSWindow,
        width: CGFloat,
        label: String,
        completion: @escaping (LayoutSnapshot) -> Void
    ) {
        window.setContentSize(NSSize(width: width, height: max(window.contentLayoutRect.height, 720)))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            window.layoutIfNeeded()
            window.contentView?.layoutSubtreeIfNeeded()
            let widths = self.captureControlWidths(in: window)
            let overflow = self.captureControlOverflow(in: window)
            let screenshotURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".build/layout-verify-\(label).png")
            self.saveSnapshot(of: window, to: screenshotURL)
            print("LAYOUT-\(label.uppercased()): \(self.serialized(widths))")
            print("LAYOUT-\(label.uppercased())-OVERFLOW: \(self.serialized(overflow))")
            print("LAYOUT-\(label.uppercased())-SNAPSHOT: \(screenshotURL.path)")
            completion(LayoutSnapshot(widths: widths, overflow: overflow))
        }
    }

    private func finish(window: NSWindow, minimum: LayoutSnapshot, medium: LayoutSnapshot, wide: LayoutSnapshot) {
        let screenshotURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/layout-verify.png")

        saveSnapshot(of: window, to: screenshotURL)
        print("LAYOUT-SNAPSHOT: \(screenshotURL.path)")

        let trackedKeys = [
            "button:Open",
            "button:Save",
            "button:Recent",
            "button:Export",
            "segmented:Split|Markdown|Preview"
        ]

        let maxDelta = trackedKeys.compactMap { key -> CGFloat? in
            guard let first = minimum.widths[key], let second = wide.widths[key] else {
                return nil
            }

            return abs(first - second)
        }.max() ?? .greatestFiniteMagnitude

        let maxOverflow = trackedKeys.compactMap { minimum.overflow[$0] }.max() ?? .greatestFiniteMagnitude
        let mediumMaxOverflow = trackedKeys.compactMap { medium.overflow[$0] }.max() ?? .greatestFiniteMagnitude

        if maxDelta <= 1.0, maxOverflow <= 1.0, mediumMaxOverflow <= 1.0 {
            print("LAYOUT-VERIFY: PASS max_delta=\(String(format: "%.1f", maxDelta)) max_overflow=\(String(format: "%.1f", maxOverflow)) medium_overflow=\(String(format: "%.1f", mediumMaxOverflow))")
            fflush(stdout)
            NSApp.terminate(nil)
        } else {
            print("LAYOUT-VERIFY: FAIL max_delta=\(String(format: "%.1f", maxDelta)) max_overflow=\(String(format: "%.1f", maxOverflow)) medium_overflow=\(String(format: "%.1f", mediumMaxOverflow))")
            fflush(stdout)
            exit(1)
        }
    }

    private func saveSnapshot(of window: NSWindow, to url: URL) {
        guard let contentView = window.contentView else {
            return
        }

        let bounds = contentView.bounds
        guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return
        }

        contentView.cacheDisplay(in: bounds, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            return
        }

        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }

    private func captureControlWidths(in window: NSWindow) -> [String: CGFloat] {
        guard let contentView = window.contentView else {
            return [:]
        }

        var widths: [String: CGFloat] = [:]

        for view in allSubviews(of: contentView) {
            if let key = controlKey(for: view) {
                widths[key] = round(view.frame.width * 10) / 10
            }
        }

        return widths
    }

    private func captureControlOverflow(in window: NSWindow) -> [String: CGFloat] {
        guard let contentView = window.contentView else {
            return [:]
        }

        var overflow: [String: CGFloat] = [:]

        for view in allSubviews(of: contentView) {
            guard let key = controlKey(for: view) else {
                continue
            }

            let frame = view.convert(view.bounds, to: contentView)
            let clippedWidth = max(0, frame.maxX - contentView.bounds.maxX)
            overflow[key] = round(clippedWidth * 10) / 10
        }

        return overflow
    }

    private func controlKey(for view: NSView) -> String? {
        if let segmented = view as? NSSegmentedControl {
            let labels = (0..<segmented.segmentCount).map { segmented.label(forSegment: $0) ?? "" }
            return "segmented:\(labels.joined(separator: "|"))"
        }

        if let popup = view as? NSPopUpButton {
            let title = popup.selectedItem?.title ?? popup.titleOfSelectedItem ?? "popup"
            return "popup:\(title)"
        }

        if let button = view as? NSButton, !button.title.isEmpty {
            return "button:\(button.title)"
        }

        return nil
    }

    private func allSubviews(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(allSubviews)
    }

    private func serialized(_ values: [String: CGFloat]) -> String {
        values.keys.sorted().map { key in
            "\(key)=\(String(format: "%.1f", values[key] ?? 0))"
        }.joined(separator: ", ")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var documentController: DocumentController?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let documentController else {
            return .terminateNow
        }

        return documentController.canTerminateApplication() ? .terminateNow : .terminateCancel
    }
}

@main
struct MDViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var document = DocumentController()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(document)
                .onAppear {
                    appDelegate.documentController = document
                }
        }
        .commands {
            AppCommands(document: document)
        }

        Settings {
            ThemeSettingsView()
        }
    }
}

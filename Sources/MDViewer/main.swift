import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

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
    case smooth

    var id: Self { self }

    var title: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .smooth:
            return "Smooth"
        }
    }

    var backgroundColor: Color {
        Color(nsColor: nsBackgroundColor)
    }

    var secondaryBackgroundColor: Color {
        switch self {
        case .light:
            return Color(nsColor: NSColor(calibratedWhite: 0.96, alpha: 1))
        case .dark:
            return Color(nsColor: NSColor(calibratedWhite: 0.07, alpha: 1))
        case .smooth:
            return Color(nsColor: NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.31, alpha: 1))
        }
    }

    var dividerColor: Color {
        switch self {
        case .light:
            return Color.black.opacity(0.12)
        case .dark:
            return Color.white.opacity(0.10)
        case .smooth:
            return Color.white.opacity(0.14)
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .light:
            return Color.black.opacity(0.92)
        case .dark, .smooth:
            return Color.white.opacity(0.92)
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light:
            return Color.black.opacity(0.62)
        case .dark, .smooth:
            return Color.white.opacity(0.72)
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark, .smooth:
            return .dark
        }
    }

    var windowAppearanceName: NSAppearance.Name {
        switch self {
        case .light:
            return .aqua
        case .dark, .smooth:
            return .darkAqua
        }
    }

    var nsBackgroundColor: NSColor {
        switch self {
        case .light:
            return .white
        case .dark:
            return .black
        case .smooth:
            return NSColor(calibratedRed: 41 / 255, green: 45 / 255, blue: 62 / 255, alpha: 1)
        }
    }
}

@MainActor
final class DocumentController: ObservableObject {
    private enum DefaultsKey {
        static let lastOpenDocumentPath = "lastOpenDocumentPath"
        static let reopenLastFileOnLaunch = "reopenLastFileOnLaunch"
    }

    @Published var text = "" {
        didSet {
            updateDirtyState()
        }
    }
    @Published var fileURL: URL? {
        didSet {
            persistLastOpenDocumentURLIfNeeded()
        }
    }
    @Published private(set) var recentDocumentURLs: [URL] = []
    @Published private(set) var isDirty = false
    @Published var reopenLastFileOnLaunch: Bool {
        didSet {
            persistLaunchPreferences()
        }
    }

    private let defaults = UserDefaults.standard
    private var savedText = ""
    private var suppressDirtyStateUpdates = false

    init() {
        if defaults.object(forKey: DefaultsKey.reopenLastFileOnLaunch) == nil {
            reopenLastFileOnLaunch = true
        } else {
            reopenLastFileOnLaunch = defaults.bool(forKey: DefaultsKey.reopenLastFileOnLaunch)
        }

        refreshRecentDocuments()
        restoreLastSessionIfNeeded()
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

    private func restoreLastSessionIfNeeded() {
        guard reopenLastFileOnLaunch else {
            return
        }

        guard let path = defaults.string(forKey: DefaultsKey.lastOpenDocumentPath) else {
            return
        }

        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: url.path) else {
            defaults.removeObject(forKey: DefaultsKey.lastOpenDocumentPath)
            return
        }

        openDocument(at: url, noteAsRecent: false)
    }

    private func persistLaunchPreferences() {
        defaults.set(reopenLastFileOnLaunch, forKey: DefaultsKey.reopenLastFileOnLaunch)
        persistLastOpenDocumentURLIfNeeded()
    }

    private func persistLastOpenDocumentURLIfNeeded() {
        guard reopenLastFileOnLaunch, let url = fileURL else {
            defaults.removeObject(forKey: DefaultsKey.lastOpenDocumentPath)
            return
        }

        defaults.set(url.path, forKey: DefaultsKey.lastOpenDocumentPath)
    }

    private func present(_ error: Error, title: String) {
        let alert = NSAlert(error: error)
        alert.messageText = title
        alert.runModal()
    }
}

struct ContentView: View {
    @EnvironmentObject private var document: DocumentController
    @AppStorage("viewMode") private var viewModeRawValue = ViewMode.split.rawValue
    @AppStorage("themeMode") private var themeModeRawValue = ThemeMode.light.rawValue
    @State private var isDropTargeted = false

    private var viewMode: ViewMode {
        ViewMode(rawValue: viewModeRawValue) ?? .split
    }

    private var themeMode: ThemeMode {
        ThemeMode(rawValue: themeModeRawValue) ?? .light
    }

    private var viewModeBinding: Binding<ViewMode> {
        Binding(
            get: { viewMode },
            set: { viewModeRawValue = $0.rawValue }
        )
    }

    private var themeModeBinding: Binding<ThemeMode> {
        Binding(
            get: { themeMode },
            set: { themeModeRawValue = $0.rawValue }
        )
    }

    private var reopenLastFileBinding: Binding<Bool> {
        Binding(
            get: { document.reopenLastFileOnLaunch },
            set: { document.reopenLastFileOnLaunch = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            controlStrip
            Rectangle()
                .fill(themeMode.dividerColor)
                .frame(height: 1)

            Group {
                switch viewMode {
                case .split:
                    HSplitView {
                        editorPane
                        previewPane
                    }
                case .editor:
                    editorPane
                case .preview:
                    previewPane
                }
            }
        }
        .background(themeMode.backgroundColor)
        .background(WindowConfigurationView(themeMode: themeMode, document: document))
        .frame(minWidth: 600, minHeight: 400)
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

    private var controlStrip: some View {
        HStack(spacing: 10) {
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

            Divider()
                .frame(height: 18)

            HStack(spacing: 8) {
                Text("View")
                    .foregroundStyle(themeMode.secondaryTextColor)

                Picker("View", selection: viewModeBinding) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 8) {
                Text("Theme")
                    .foregroundStyle(themeMode.secondaryTextColor)

                Picker("Theme", selection: themeModeBinding) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .fixedSize(horizontal: true, vertical: false)

            Toggle("Reopen Last File", isOn: reopenLastFileBinding)
                .toggleStyle(.switch)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                Circle()
                    .fill(document.isDirty ? Color.orange : themeMode.secondaryTextColor.opacity(0.45))
                    .frame(width: 7, height: 7)

                Text(document.currentDocumentStatusText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(themeMode.secondaryTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(themeMode.dividerColor.opacity(themeMode == .light ? 0.65 : 1))
            .clipShape(Capsule())
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeMode.secondaryBackgroundColor)
        .environment(\.colorScheme, themeMode.colorScheme)
    }

    private var editorPane: some View {
        ZStack {
            themeMode.backgroundColor

            TextEditor(text: $document.text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .foregroundStyle(themeMode.primaryTextColor)
                .background(themeMode.backgroundColor)
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

struct WindowConfigurationView: NSViewRepresentable {
    let themeMode: ThemeMode
    let document: DocumentController

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            context.coordinator.configureWindow(for: view, themeMode: themeMode)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.document = document

        DispatchQueue.main.async {
            context.coordinator.configureWindow(for: nsView, themeMode: themeMode)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        var document: DocumentController
        weak var window: NSWindow?

        init(document: DocumentController) {
            self.document = document
        }

        func configureWindow(for view: NSView, themeMode: ThemeMode) {
            guard let window = view.window else {
                return
            }

            if self.window !== window || window.delegate !== self {
                window.delegate = self
                self.window = window
            }

            window.appearance = NSAppearance(named: themeMode.windowAppearanceName)
            window.backgroundColor = themeMode.nsBackgroundColor
            window.title = document.currentDocumentName
            window.representedURL = document.fileURL
            window.isDocumentEdited = document.isDirty
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false

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

struct AppCommands: Commands {
    @ObservedObject var document: DocumentController

    private var reopenLastFileBinding: Binding<Bool> {
        Binding(
            get: { document.reopenLastFileOnLaunch },
            set: { document.reopenLastFileOnLaunch = $0 }
        )
    }

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

        CommandMenu("Options") {
            Toggle("Reopen Last File on Launch", isOn: reopenLastFileBinding)
        }
    }
}

@MainActor
final class LayoutVerificationRunner {
    static let shared = LayoutVerificationRunner()

    private let isEnabled = ProcessInfo.processInfo.environment["MDVIEWER_VERIFY_TOPBAR_RESIZE"] == "1"
    private var hasStarted = false

    func scheduleIfNeeded(window: NSWindow) {
        guard isEnabled, !hasStarted else {
            return
        }

        hasStarted = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.measure(window: window, width: 900, label: "narrow") { narrowWidths in
                self.measure(window: window, width: 1500, label: "wide") { wideWidths in
                    self.finish(narrow: narrowWidths, wide: wideWidths)
                }
            }
        }
    }

    private func measure(
        window: NSWindow,
        width: CGFloat,
        label: String,
        completion: @escaping ([String: CGFloat]) -> Void
    ) {
        var frame = window.frame
        frame.size.width = width
        frame.size.height = max(frame.size.height, 720)
        window.setFrame(frame, display: true, animate: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            window.layoutIfNeeded()
            window.contentView?.layoutSubtreeIfNeeded()
            let widths = self.captureControlWidths(in: window)
            print("LAYOUT-\(label.uppercased()): \(self.serialized(widths))")
            completion(widths)
        }
    }

    private func finish(narrow: [String: CGFloat], wide: [String: CGFloat]) {
        let screenshotURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/layout-verify.png")

        if let window = NSApp.windows.first {
            saveSnapshot(of: window, to: screenshotURL)
            print("LAYOUT-SNAPSHOT: \(screenshotURL.path)")
        }

        let trackedKeys = [
            "button:Open",
            "button:Save",
            "button:Recent",
            "button:Export",
            "button:Reopen Last File",
            "segmented:Split|Markdown|Preview"
        ]

        let maxDelta = trackedKeys.compactMap { key -> CGFloat? in
            guard let first = narrow[key], let second = wide[key] else {
                return nil
            }

            return abs(first - second)
        }.max() ?? .greatestFiniteMagnitude

        if maxDelta <= 1.0 {
            print("LAYOUT-VERIFY: PASS max_delta=\(String(format: "%.1f", maxDelta))")
            fflush(stdout)
            NSApp.terminate(nil)
        } else {
            print("LAYOUT-VERIFY: FAIL max_delta=\(String(format: "%.1f", maxDelta))")
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
            if let segmented = view as? NSSegmentedControl {
                let labels = (0..<segmented.segmentCount).map { segmented.label(forSegment: $0) ?? "" }
                let key = "segmented:\(labels.joined(separator: "|"))"
                widths[key] = round(segmented.frame.width * 10) / 10
            } else if let popup = view as? NSPopUpButton {
                let title = popup.selectedItem?.title ?? popup.titleOfSelectedItem ?? "popup"
                widths["popup:\(title)"] = round(popup.frame.width * 10) / 10
            } else if let button = view as? NSButton, !button.title.isEmpty {
                widths["button:\(button.title)"] = round(button.frame.width * 10) / 10
            }
        }

        return widths
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
    }
}

#!/usr/bin/swift

import Foundation

struct IconSpec {
    let filename: String
    let size: Int
}

let specs = [
    IconSpec(filename: "icon_16x16.png", size: 16),
    IconSpec(filename: "icon_16x16@2x.png", size: 32),
    IconSpec(filename: "icon_32x32.png", size: 32),
    IconSpec(filename: "icon_32x32@2x.png", size: 64),
    IconSpec(filename: "icon_128x128.png", size: 128),
    IconSpec(filename: "icon_128x128@2x.png", size: 256),
    IconSpec(filename: "icon_256x256.png", size: 256),
    IconSpec(filename: "icon_256x256@2x.png", size: 512),
    IconSpec(filename: "icon_512x512.png", size: 512),
    IconSpec(filename: "icon_512x512@2x.png", size: 1024)
]

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let iconDirectory = rootURL.appendingPathComponent("icon", isDirectory: true)
let sourceURL = iconDirectory.appendingPathComponent("icon.png")
let previewURL = iconDirectory.appendingPathComponent("AppIcon-1024.png")
let iconsetDirectory = iconDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = iconDirectory.appendingPathComponent("AppIcon.icns")

guard fileManager.fileExists(atPath: sourceURL.path) else {
    throw NSError(
        domain: "IconGenerator",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing source icon at \(sourceURL.path)"]
    )
}

try fileManager.createDirectory(at: iconDirectory, withIntermediateDirectories: true)

if fileManager.fileExists(atPath: iconsetDirectory.path) {
    try fileManager.removeItem(at: iconsetDirectory)
}

try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

if fileManager.fileExists(atPath: previewURL.path) {
    try fileManager.removeItem(at: previewURL)
}

try fileManager.copyItem(at: sourceURL, to: previewURL)

for spec in specs {
    try run(
        executable: "/usr/bin/sips",
        arguments: [
            "-z", "\(spec.size)", "\(spec.size)",
            sourceURL.path,
            "--out", iconsetDirectory.appendingPathComponent(spec.filename).path
        ]
    )
}

if fileManager.fileExists(atPath: icnsURL.path) {
    try fileManager.removeItem(at: icnsURL)
}

let icnsData = try buildICNS(from: [
    ("icp4", iconsetDirectory.appendingPathComponent("icon_16x16.png")),
    ("icp5", iconsetDirectory.appendingPathComponent("icon_32x32.png")),
    ("icp6", iconsetDirectory.appendingPathComponent("icon_32x32@2x.png")),
    ("ic07", iconsetDirectory.appendingPathComponent("icon_128x128.png")),
    ("ic08", iconsetDirectory.appendingPathComponent("icon_128x128@2x.png")),
    ("ic09", iconsetDirectory.appendingPathComponent("icon_256x256@2x.png")),
    ("ic10", iconsetDirectory.appendingPathComponent("icon_512x512@2x.png"))
])
try icnsData.write(to: icnsURL)

print("Generated icon assets from \(sourceURL.path)")

func buildICNS(from entries: [(String, URL)]) throws -> Data {
    var chunks = Data()

    for (type, url) in entries {
        let pngData = try Data(contentsOf: url)
        chunks.append(Data(type.utf8))
        chunks.append(bigEndianData(UInt32(pngData.count + 8)))
        chunks.append(pngData)
    }

    var data = Data()
    data.append(Data("icns".utf8))
    data.append(bigEndianData(UInt32(chunks.count + 8)))
    data.append(chunks)

    return data
}

func bigEndianData(_ value: UInt32) -> Data {
    var number = value.bigEndian
    return Data(bytes: &number, count: MemoryLayout<UInt32>.size)
}

func run(executable: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw NSError(
            domain: "IconGenerator",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "\(URL(fileURLWithPath: executable).lastPathComponent) failed with status \(process.terminationStatus)"]
        )
    }
}

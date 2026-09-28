#!/usr/bin/env swift

import AVFoundation
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: inspect_media.swift <reels-directory>\n", stderr)
    exit(2)
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let files = try FileManager.default.contentsOfDirectory(
    at: directory,
    includingPropertiesForKeys: [.fileSizeKey],
    options: [.skipsHiddenFiles]
).filter { $0.pathExtension.lowercased() == "mp4" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

print("file,duration_seconds,width,height,video_codec,audio_tracks,size_bytes,status")
var failures = 0
for file in files {
    let asset = AVURLAsset(url: file)
    let duration = CMTimeGetSeconds(asset.duration)
    let videoTracks = asset.tracks(withMediaType: .video)
    let audioTracks = asset.tracks(withMediaType: .audio)
    let track = videoTracks.first
    let size = track?.naturalSize.applying(track?.preferredTransform ?? .identity) ?? .zero
    let displayWidth = Int(abs(size.width).rounded())
    let displayHeight = Int(abs(size.height).rounded())
    var codec = "unknown"
    if let rawDescription = track?.formatDescriptions.first {
        let description = rawDescription as! CMFormatDescription
        let subtype = CMFormatDescriptionGetMediaSubType(description)
        codec = String(format: "%c%c%c%c", (subtype >> 24) & 0xff, (subtype >> 16) & 0xff, (subtype >> 8) & 0xff, subtype & 0xff)
    }
    let bytes = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    let ok = abs(duration - 12.0) < 0.1 && displayWidth == 1080 && displayHeight == 1920 && codec == "avc1"
    if !ok { failures += 1 }
    print("\(file.lastPathComponent),\(String(format: "%.3f", duration)),\(displayWidth),\(displayHeight),\(codec),\(audioTracks.count),\(bytes),\(ok ? "PASS" : "FAIL")")
}
fputs("Inspected \(files.count) files; failures: \(failures)\n", stderr)
exit(failures == 0 && files.count == 30 ? 0 : 1)

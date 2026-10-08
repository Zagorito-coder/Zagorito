#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: make_contact_sheet.swift <covers-directory> <output.png>\n", stderr)
    exit(2)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let files = try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard files.count == 30 else { fatalError("Expected 30 covers, found \(files.count)") }

let width = 1080
let height = 1600
let columns = 6
let thumbWidth = width / columns
let thumbHeight = 320
let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Unable to create context") }
context.setFillColor(CGColor(red: 0.005, green: 0.02, blue: 0.06, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

for (index, file) in files.enumerated() {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Unable to read \(file.path)")
    }
    let column = index % columns
    let row = index / columns
    let rect = CGRect(
        x: column * thumbWidth,
        y: height - (row + 1) * thumbHeight,
        width: thumbWidth,
        height: thumbHeight
    )
    context.interpolationQuality = .high
    context.draw(image, in: rect)
}

guard let sheet = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Unable to create output")
}
CGImageDestinationAddImage(destination, sheet, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Unable to write output") }

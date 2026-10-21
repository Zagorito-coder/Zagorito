#!/usr/bin/env swift

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: make_contact_sheet.swift <exports> <output.png>")
}
let input = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let files = try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard files.count == 20 else { fatalError("20 exports attendus, \(files.count) trouvés") }

let columns = 5
let rows = 4
let thumbWidth = 270
let thumbHeight = 338
let labelHeight = 36
let width = columns * thumbWidth
let height = rows * (thumbHeight + labelHeight)
guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Contexte indisponible") }
context.setFillColor(CGColor(red: 0.005, green: 0.02, blue: 0.06, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

for (index, file) in files.enumerated() {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Lecture impossible: \(file.path)") }
    let column = index % columns
    let row = index / columns
    let x = column * thumbWidth
    let y = height - (row + 1) * (thumbHeight + labelHeight) + labelHeight
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: x, y: y, width: thumbWidth, height: thumbHeight))
    let font = CTFontCreateWithName("AvenirNext-DemiBold" as CFString, 18, nil)
    let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.9, alpha: 1)]
    let text = NSAttributedString(string: file.deletingPathExtension().lastPathComponent, attributes: attrs)
    let line = CTLineCreateWithAttributedString(text)
    context.textPosition = CGPoint(x: x + 12, y: y - 26)
    CTLineDraw(line, context)
}

guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("Sortie indisponible") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Écriture impossible") }

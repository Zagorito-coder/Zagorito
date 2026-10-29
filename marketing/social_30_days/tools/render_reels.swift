#!/usr/bin/env swift

import AppKit
import AVFoundation
import CoreGraphics
import CoreText
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Post: Decodable {
    let day: Int
    let slug: String
    let series: String
    let language: String
    let objective: String
    let background: String
    let screenBackgrounds: [String]?
    let screens: [String]
    let voiceover: String
    let caption: String
    let cta: String
    let hashtags: String
}

let width = 1080
let height = 1920
let fps: Int32 = 30
let secondsPerCard = 3
let framesPerCard = Int(fps) * secondsPerCard
let cyan = CGColor(red: 0.04, green: 0.80, blue: 0.96, alpha: 1)
let white = CGColor(red: 0.97, green: 0.99, blue: 1, alpha: 1)
let muted = CGColor(red: 0.71, green: 0.78, blue: 0.88, alpha: 1)
let navy = CGColor(red: 0.01, green: 0.04, blue: 0.10, alpha: 1)

func die(_ message: String) -> Never {
    FileHandle.standardError.write(("ERROR: \(message)\n").data(using: .utf8)!)
    exit(1)
}

func loadCGImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        die("Unable to read image: \(url.path)")
    }
    return image
}

func aspectFillRect(image: CGImage, canvas: CGRect) -> CGRect {
    let iw = CGFloat(image.width)
    let ih = CGFloat(image.height)
    let scale = max(canvas.width / iw, canvas.height / ih)
    let w = iw * scale
    let h = ih * scale
    return CGRect(x: canvas.midX - w / 2, y: canvas.midY - h / 2, width: w, height: h)
}

func containsArabic(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        (0x0600...0x06FF).contains(Int(scalar.value)) ||
        (0x0750...0x077F).contains(Int(scalar.value)) ||
        (0x08A0...0x08FF).contains(Int(scalar.value))
    }
}

func drawText(
    _ text: String,
    context: CGContext,
    rect: CGRect,
    size: CGFloat,
    color: CGColor,
    bold: Bool,
    alignment: CTTextAlignment,
    direction: CTWritingDirection? = nil,
    lineSpacing: CGFloat = 14
) {
    context.saveGState()
    defer { context.restoreGState() }
    context.textMatrix = .identity
    let fontName: String
    if containsArabic(text) {
        fontName = bold ? "SFArabic-Semibold" : "SFArabic-Regular"
    } else {
        fontName = bold ? "Arial-BoldMT" : "ArialMT"
    }
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let style = NSMutableParagraphStyle()
    switch alignment {
    case .right: style.alignment = .right
    case .center: style.alignment = .center
    case .justified: style.alignment = .justified
    default: style.alignment = .left
    }
    style.baseWritingDirection = direction == .rightToLeft ? .rightToLeft : .leftToRight
    style.lineSpacing = lineSpacing
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        .paragraphStyle: style,
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let path = CGPath(rect: rect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributed.length), path, nil)
    CTFrameDraw(frame, context)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func makePixelBuffer(pool: CVPixelBufferPool) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard status == kCVReturnSuccess, let result = buffer else {
        die("Unable to allocate video pixel buffer (\(status))")
    }
    return result
}

func renderCard(
    pool: CVPixelBufferPool,
    background: CGImage,
    logo: CGImage,
    post: Post,
    cardIndex: Int
) -> CVPixelBuffer {
    let buffer = makePixelBuffer(pool: pool)
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer),
          let context = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
          ) else {
        die("Unable to create drawing context")
    }

    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(navy)
    context.fill(canvas)
    context.interpolationQuality = .high
    context.draw(background, in: aspectFillRect(image: background, canvas: canvas))

    let gradientColors = [
        CGColor(red: 0.005, green: 0.025, blue: 0.07, alpha: 0.96),
        CGColor(red: 0.005, green: 0.025, blue: 0.07, alpha: 0.36),
        CGColor(red: 0.005, green: 0.025, blue: 0.07, alpha: 0.90),
    ] as CFArray
    let locations: [CGFloat] = [0, 0.48, 1]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: locations)!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])

    // Header kept inside the Meta safe zone.
    context.saveGState()
    context.addPath(roundedRect(CGRect(x: 70, y: 1690, width: 940, height: 150), radius: 52))
    context.setFillColor(CGColor(red: 0.015, green: 0.07, blue: 0.14, alpha: 0.82))
    context.fillPath()
    context.draw(logo, in: CGRect(x: 100, y: 1710, width: 110, height: 110))
    drawText("BOOSTERFISH", context: context, rect: CGRect(x: 235, y: 1742, width: 420, height: 54), size: 40, color: white, bold: true, alignment: .left, lineSpacing: 5)
    drawText(String(format: "JOUR %02d / 30", post.day), context: context, rect: CGRect(x: 710, y: 1745, width: 250, height: 46), size: 27, color: cyan, bold: true, alignment: .right, lineSpacing: 4)
    context.restoreGState()

    // Series chip.
    context.addPath(roundedRect(CGRect(x: 90, y: 1485, width: 650, height: 74), radius: 34))
    context.setFillColor(CGColor(red: 0.02, green: 0.58, blue: 0.80, alpha: 0.92))
    context.fillPath()
    let seriesArabic = containsArabic(post.series)
    drawText(
        post.series,
        context: context,
        rect: CGRect(x: 120, y: 1494, width: 590, height: 58),
        size: 26,
        color: white,
        bold: true,
        alignment: seriesArabic ? .right : .left,
        direction: seriesArabic ? .rightToLeft : .leftToRight,
        lineSpacing: 4
    )

    let screen = post.screens[cardIndex]
    let isArabic = containsArabic(screen)
    let alignment: CTTextAlignment = isArabic ? .right : .left
    let direction: CTWritingDirection = isArabic ? .rightToLeft : .leftToRight

    // Main message panel.
    let messageRect = CGRect(x: 70, y: 610, width: 940, height: 740)
    context.addPath(roundedRect(messageRect, radius: 58))
    context.setFillColor(CGColor(red: 0.005, green: 0.025, blue: 0.075, alpha: 0.72))
    context.fillPath()
    context.setStrokeColor(CGColor(red: 0.04, green: 0.80, blue: 0.96, alpha: 0.55))
    context.setLineWidth(3)
    context.addPath(roundedRect(messageRect, radius: 58))
    context.strokePath()

    let titleSize: CGFloat = screen.count > 45 ? 72 : (screen.count > 30 ? 82 : 92)
    drawText(
        screen,
        context: context,
        rect: CGRect(x: 125, y: 790, width: 830, height: 390),
        size: titleSize,
        color: white,
        bold: true,
        alignment: alignment,
        direction: direction,
        lineSpacing: 20
    )

    let helper: String
    if cardIndex == 0 {
        helper = post.language
    } else if cardIndex == 3 {
        helper = post.cta
    } else {
        helper = "PRÉPARER • COMPRENDRE • DÉCIDER"
    }
    let helperArabic = containsArabic(helper)
    drawText(
        helper,
        context: context,
        rect: CGRect(x: 125, y: 690, width: 830, height: 60),
        size: helper.count > 34 ? 25 : 30,
        color: cyan,
        bold: true,
        alignment: helperArabic ? .right : .left,
        direction: helperArabic ? .rightToLeft : .leftToRight,
        lineSpacing: 6
    )

    // Footer and progress indicator, also inside safe area.
    drawText("En test fermé • Bientôt disponible", context: context, rect: CGRect(x: 90, y: 350, width: 900, height: 55), size: 30, color: muted, bold: false, alignment: .center, lineSpacing: 5)
    let barWidth: CGFloat = 202
    for index in 0..<4 {
        let rect = CGRect(x: 90 + CGFloat(index) * 225, y: 260, width: barWidth, height: 12)
        context.addPath(roundedRect(rect, radius: 6))
        context.setFillColor(index <= cardIndex ? cyan : CGColor(red: 0.35, green: 0.42, blue: 0.53, alpha: 0.55))
        context.fillPath()
    }
    // Redraw the brand wordmark last so complex-script shaping cannot affect it.
    drawText("BOOSTERFISH", context: context, rect: CGRect(x: 235, y: 1742, width: 420, height: 54), size: 40, color: white, bold: true, alignment: .left, direction: .leftToRight, lineSpacing: 5)
    return buffer
}

func savePNG(_ buffer: CVPixelBuffer, to url: URL) {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer),
          let context = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
          ),
          let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        die("Unable to create cover: \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        die("Unable to finalize cover: \(url.path)")
    }
}

func renderVideo(post: Post, root: URL, logo: CGImage) {
    let reels = root.appendingPathComponent("exports/reels")
    let covers = root.appendingPathComponent("exports/covers")
    let source = root.appendingPathComponent("source_assets")
    let name = String(format: "%02d_%@", post.day, post.slug)
    let videoURL = reels.appendingPathComponent(name + ".mp4")
    let coverURL = covers.appendingPathComponent(name + ".png")
    try? FileManager.default.removeItem(at: videoURL)

    let writer: AVAssetWriter
    do { writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4) }
    catch { die("Unable to create writer for \(name): \(error)") }

    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 6_000_000,
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: Int(fps) * 3,
        ],
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
    guard writer.canAdd(input) else { die("Unable to add input for \(name)") }
    writer.add(input)
    guard writer.startWriting() else { die("Unable to start writer for \(name): \(String(describing: writer.error))") }
    writer.startSession(atSourceTime: .zero)
    guard let pool = adaptor.pixelBufferPool else { die("No pixel buffer pool for \(name)") }

    var cards: [CVPixelBuffer] = []
    for index in 0..<4 {
        let backgroundName = post.screenBackgrounds?[index] ?? post.background
        let background = loadCGImage(source.appendingPathComponent(backgroundName))
        cards.append(renderCard(pool: pool, background: background, logo: logo, post: post, cardIndex: index))
    }
    savePNG(cards[0], to: coverURL)

    var frameIndex: Int64 = 0
    for card in cards {
        for _ in 0..<framesPerCard {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
            let time = CMTime(value: frameIndex, timescale: fps)
            if !adaptor.append(card, withPresentationTime: time) {
                die("Append failed for \(name): \(writer.error?.localizedDescription ?? "unknown")")
            }
            frameIndex += 1
        }
    }
    input.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting { semaphore.signal() }
    semaphore.wait()
    guard writer.status == .completed else {
        die("Encoding failed for \(name): \(writer.error?.localizedDescription ?? "unknown")")
    }
    print("Rendered \(name)")
}

guard CommandLine.arguments.count >= 2 else {
    die("Usage: render_reels.swift <marketing/social_30_days> [day]")
}
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let dataURL = root.appendingPathComponent("content/posts.json")
let data = try Data(contentsOf: dataURL)
let allPosts = try JSONDecoder().decode([Post].self, from: data)
let requestedDay = CommandLine.arguments.count >= 3 ? Int(CommandLine.arguments[2]) : nil
let posts = requestedDay == nil ? allPosts : allPosts.filter { $0.day == requestedDay }
guard !posts.isEmpty else { die("No matching post") }
let logo = loadCGImage(root.appendingPathComponent("source_assets/logo.png"))
for post in posts { renderVideo(post: post, root: root, logo: logo) }

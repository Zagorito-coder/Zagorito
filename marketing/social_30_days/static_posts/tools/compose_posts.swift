#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Post {
    let id: Int
    let file: String
    let category: String
    let title: String
    let subtitle: String
    let status: String
}

let posts: [Post] = [
    .init(id: 1, file: "01_spots_officiels.png", category: "CARTOGRAPHIE", title: "6 000+ SPOTS\nOFFICIELS", subtitle: "Explorez le littoral. Préparez votre zone.", status: "CATALOGUE OFFICIEL"),
    .init(id: 2, file: "02_spots_prives.png", category: "CONFIDENTIALITÉ", title: "VOS SPOTS\nRESTENT PRIVÉS", subtitle: "Vos coordonnées restent dans votre compte.", status: "REPÈRES PERSONNELS"),
    .init(id: 3, file: "03_marees.png", category: "MARÉES", title: "LIRE LA MARÉE", subtitle: "Heure • hauteur • évolution", status: "PRÉPARER SA SORTIE"),
    .init(id: 4, file: "04_conditions_marines.png", category: "CONDITIONS MARINES", title: "LIRE LA MER", subtitle: "Vent • vagues • marées", status: "DÉCIDER AVANT DE PARTIR"),
    .init(id: 5, file: "05_cartes_hors_ligne.png", category: "HORS LIGNE", title: "PRÉPAREZ LE\nHORS LIGNE", subtitle: "Téléchargez avant de quitter le réseau.", status: "PENSÉ POUR LE LITTORAL"),
    .init(id: 6, file: "06_techniques.png", category: "TECHNIQUES", title: "18 TECHNIQUES\n& MONTAGES", subtitle: "Des gestes clairs, étape par étape.", status: "GUIDES VISUELS"),
    .init(id: 7, file: "07_noeud_fg.png", category: "NŒUDS", title: "NŒUD FG", subtitle: "Tresse et bas de ligne, avec méthode.", status: "APPRENDRE • SERRER • TESTER"),
    .init(id: 8, file: "08_palomar.png", category: "NŒUDS", title: "NŒUD PALOMAR", subtitle: "Apprenez. Serrez. Testez.", status: "GUIDE PAS À PAS"),
    .init(id: 9, file: "09_jigging.png", category: "JIGGING", title: "PRÉPARATION\nJIGGING", subtitle: "Ligne • anneaux • hameçons • frein", status: "MATÉRIEL & MÉTHODE"),
    .init(id: 10, file: "10_traine_big_game.png", category: "TRAÎNE", title: "PRÉPARATION\nBIG GAME", subtitle: "Thon • marlin • espadon", status: "MATÉRIEL & MÉTHODE"),
    .init(id: 11, file: "11_especes.png", category: "ESPÈCES", title: "CONNAÎTRE\nL’ESPÈCE", subtitle: "Observer. Identifier. Respecter.", status: "FICHES POISSONS"),
    .init(id: 12, file: "12_communaute.png", category: "COMMUNAUTÉ", title: "ENTRE\nPÊCHEURS", subtitle: "Partagez l’expérience. Gardez le spot privé.", status: "COMMUNAUTÉ MODÉRÉE"),
    .init(id: 13, file: "13_partage_prise.png", category: "CARNET DE SORTIE", title: "VOTRE SORTIE,\nVOTRE HISTOIRE", subtitle: "Photo • espèce • récit", status: "PARTAGER L’EXPÉRIENCE"),
    .init(id: 14, file: "14_securite.png", category: "SÉCURITÉ", title: "AVANT LE\nPREMIER LANCER", subtitle: "Préparez l’équipement avant de partir.", status: "LA MER SE PRÉPARE"),
    .init(id: 15, file: "15_magasins.png", category: "À PROXIMITÉ", title: "LE MATÉRIEL\nPRÈS DE VOUS", subtitle: "Repérez les magasins de pêche.", status: "PRÉPARER SON ÉQUIPEMENT"),
    .init(id: 16, file: "16_carnet.png", category: "HISTORIQUE", title: "VOTRE MÉMOIRE\nDE PÊCHE", subtitle: "Retrouvez vos repères, sortie après sortie.", status: "VOTRE CARNET PERSONNEL"),
    .init(id: 17, file: "17_peche_responsable.png", category: "PÊCHE RESPONSABLE", title: "RESPECTER\nLA MER", subtitle: "Préserver aujourd’hui. Revenir demain.", status: "GESTES RESPONSABLES"),
    .init(id: 18, file: "18_test_ferme.png", category: "BÊTA", title: "BOOSTERFISH\nEN TEST FERMÉ", subtitle: "Chaque retour prépare une app plus fiable.", status: "TEST GOOGLE PLAY"),
    .init(id: 19, file: "19_tout_en_un.png", category: "TOUT-EN-UN", title: "UNE SEULE APP\nPOUR VOTRE SORTIE", subtitle: "Carte • marées • espèces • techniques", status: "BOOSTERFISH"),
    .init(id: 20, file: "20_bientot.png", category: "LANCEMENT", title: "BIENTÔT\nDISPONIBLE", subtitle: "BoosterFish se prépare sur Google Play.", status: "APPLICATION DE PÊCHE EN MER"),
]

let width = 1080
let height = 1350
let navy = CGColor(red: 0.006, green: 0.025, blue: 0.065, alpha: 1)
let cyan = CGColor(red: 0.02, green: 0.80, blue: 0.98, alpha: 1)
let white = CGColor(red: 0.98, green: 0.995, blue: 1, alpha: 1)
let muted = CGColor(red: 0.76, green: 0.84, blue: 0.91, alpha: 1)

func die(_ message: String) -> Never {
    FileHandle.standardError.write(("ERROR: \(message)\n").data(using: .utf8)!)
    exit(1)
}

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { die("Impossible de lire \(url.path)") }
    return image
}

func aspectFill(_ image: CGImage, into canvas: CGRect) -> CGRect {
    let scale = max(canvas.width / CGFloat(image.width), canvas.height / CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    return CGRect(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2, width: size.width, height: size.height)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawText(_ text: String, in rect: CGRect, context: CGContext, size: CGFloat, color: CGColor, bold: Bool, alignment: CTTextAlignment = .left, lineSpacing: CGFloat = 8) {
    let font = CTFontCreateWithName((bold ? "AvenirNext-Heavy" : "AvenirNext-Medium") as CFString, size, nil)
    let style = NSMutableParagraphStyle()
    style.alignment = alignment == .center ? .center : (alignment == .right ? .right : .left)
    style.lineSpacing = lineSpacing
    style.lineBreakMode = .byWordWrapping
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        .paragraphStyle: style,
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    let setter = CTFramesetterCreateWithAttributedString(string)
    let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: string.length), CGPath(rect: rect, transform: nil), nil)
    CTFrameDraw(frame, context)
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { die("Impossible de créer \(url.path)") }
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyPNGCompressionFilter: 5] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { die("Impossible d’écrire \(url.path)") }
}

guard CommandLine.arguments.count == 4 else {
    die("Usage: compose_posts.swift <backgrounds> <logo.png> <exports>")
}
let backgroundDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let logoURL = URL(fileURLWithPath: CommandLine.arguments[2])
let exportDirectory = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
let logo = loadImage(logoURL)

for post in posts {
    let background = loadImage(backgroundDirectory.appendingPathComponent(post.file))
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { die("Contexte graphique indisponible") }
    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(navy)
    context.fill(canvas)
    context.interpolationQuality = .high
    context.draw(background, in: aspectFill(background, into: canvas))

    let overlay = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        CGColor(red: 0.003, green: 0.018, blue: 0.052, alpha: 0.98),
        CGColor(red: 0.003, green: 0.018, blue: 0.052, alpha: 0.70),
        CGColor(red: 0.003, green: 0.018, blue: 0.052, alpha: 0.06),
    ] as CFArray, locations: [0, 0.48, 1])!
    context.drawLinearGradient(overlay, start: CGPoint(x: 0, y: height), end: CGPoint(x: 820, y: 620), options: [.drawsAfterEndLocation])
    let bottom = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [CGColor(red: 0.003, green: 0.018, blue: 0.052, alpha: 0), CGColor(red: 0.003, green: 0.018, blue: 0.052, alpha: 0.88)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(bottom, start: CGPoint(x: 0, y: 360), end: CGPoint(x: 0, y: 0), options: [])

    // En-tête de marque — logo officiel, sans génération IA.
    context.saveGState()
    context.addPath(rounded(CGRect(x: 64, y: 1188, width: 900, height: 104), 32))
    context.setFillColor(CGColor(red: 0.01, green: 0.05, blue: 0.12, alpha: 0.78))
    context.fillPath()
    context.addPath(rounded(CGRect(x: 77, y: 1197, width: 86, height: 86), 22))
    context.clip()
    context.draw(logo, in: CGRect(x: 77, y: 1197, width: 86, height: 86))
    context.restoreGState()
    drawText("BOOSTERFISH", in: CGRect(x: 186, y: 1220, width: 480, height: 50), context: context, size: 34, color: white, bold: true)
    drawText(String(format: "%02d / 20", post.id), in: CGRect(x: 760, y: 1221, width: 160, height: 45), context: context, size: 26, color: cyan, bold: true, alignment: .right)

    // Catégorie.
    let chipWidth = min(CGFloat(620), max(CGFloat(230), CGFloat(post.category.count * 19 + 72)))
    context.addPath(rounded(CGRect(x: 70, y: 1074, width: chipWidth, height: 62), 31))
    context.setFillColor(CGColor(red: 0.02, green: 0.64, blue: 0.84, alpha: 0.95))
    context.fillPath()
    drawText(post.category, in: CGRect(x: 100, y: 1086, width: chipWidth - 60, height: 36), context: context, size: 22, color: white, bold: true)

    let titleSize: CGFloat = post.title.count > 27 ? 55 : (post.title.count > 19 ? 62 : 70)
    drawText(post.title, in: CGRect(x: 68, y: 745, width: 830, height: 260), context: context, size: titleSize, color: white, bold: true, lineSpacing: 5)
    context.setFillColor(cyan)
    context.fill(CGRect(x: 70, y: 704, width: 104, height: 8))
    drawText(post.subtitle, in: CGRect(x: 70, y: 603, width: 790, height: 78), context: context, size: 29, color: muted, bold: false, lineSpacing: 5)

    context.addPath(rounded(CGRect(x: 64, y: 54, width: 952, height: 92), 30))
    context.setFillColor(CGColor(red: 0.006, green: 0.035, blue: 0.09, alpha: 0.86))
    context.fillPath()
    context.setStrokeColor(CGColor(red: 0.02, green: 0.80, blue: 0.98, alpha: 0.45))
    context.setLineWidth(2)
    context.addPath(rounded(CGRect(x: 64, y: 54, width: 952, height: 92), 30))
    context.strokePath()
    drawText(post.status, in: CGRect(x: 100, y: 81, width: 760, height: 40), context: context, size: 22, color: white, bold: true)
    context.setFillColor(cyan)
    context.addEllipse(in: CGRect(x: 925, y: 87, width: 18, height: 18))
    context.fillPath()

    guard let result = context.makeImage() else { die("Image finale indisponible") }
    let name = String(format: "%02d_", post.id) + post.file.dropFirst(3)
    writePNG(result, to: exportDirectory.appendingPathComponent(name))
    print("OK \(name)")
}

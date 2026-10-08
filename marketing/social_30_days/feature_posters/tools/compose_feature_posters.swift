#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Feature { let title: String; let detail: String }
struct Poster {
    let id: Int
    let slug: String
    let background: String
    let screen: String
    let cropTop: Bool
    let kicker: String
    let title: String
    let metric: String
    let lead: String
    let features: [Feature]
    let footer: String
}

let posters: [Poster] = [
    .init(id: 1, slug: "page_spots", background: "01_spots_officiels.png", screen: "phone_map_test.png", cropTop: true, kicker: "TUTORIEL • CARTE", title: "PAGE SPOTS", metric: "6 365 spots officiels", lead: "Explorez le littoral et préparez votre zone avant le départ.", features: [.init(title: "Carte satellite", detail: "Zoomez et repérez les zones qui vous intéressent."), .init(title: "Outils de carte", detail: "Recentrez, changez de couche et activez la boussole."), .init(title: "Recherche rapide", detail: "Parcourez les spots depuis une interface dédiée.")], footer: "EXPLORE • PRÉPARE • VÉRIFIE"),
    .init(id: 2, slug: "spots_prives", background: "02_spots_prives.png", screen: "personal_spot_direct_map_phone.png", cropTop: true, kicker: "CONFIDENTIALITÉ", title: "MES SPOTS", metric: "Coordonnées privées", lead: "Enregistrez vos repères personnels sans les publier automatiquement.", features: [.init(title: "Ajout personnel", detail: "Créez un repère depuis la carte et retrouvez-le ensuite."), .init(title: "Coordonnées masquées", detail: "La position reste liée à votre compte personnel."), .init(title: "Favoris et notes", detail: "Organisez les lieux utiles pour vos prochaines sorties.")], footer: "VOTRE SPOT RESTE VOTRE SPOT"),
    .init(id: 3, slug: "marees", background: "03_marees.png", screen: "home_dark_reference.png", cropTop: true, kicker: "PRÉPARATION MARINE", title: "MARÉES", metric: "Heure • hauteur • tendance", lead: "Lisez l’évolution de la marée avant de choisir votre créneau.", features: [.init(title: "Horaires", detail: "Repérez les phases hautes et basses de la journée."), .init(title: "Hauteur", detail: "Consultez le niveau prévu pour mieux préparer l’accès."), .init(title: "Évolution", detail: "Observez la montée ou la descente, puis vérifiez sur place.")], footer: "LA MER CHANGE • VOTRE PLAN AUSSI"),
    .init(id: 4, slug: "conditions_marines", background: "04_conditions_marines.png", screen: "home_dark_reference.png", cropTop: true, kicker: "TABLEAU DE BORD", title: "CONDITIONS MARINES", metric: "Vent • mer • marées", lead: "Réunissez les principaux repères avant toute décision de sortie.", features: [.init(title: "Vent", detail: "Direction et vitesse dans un bloc lisible."), .init(title: "État de mer", detail: "Hauteur des vagues et contexte marin."), .init(title: "Décision responsable", detail: "L’application aide à préparer ; votre jugement reste essentiel.")], footer: "CONTRÔLEZ AVANT DE PARTIR"),
    .init(id: 5, slug: "cartes_hors_ligne", background: "05_cartes_hors_ligne.png", screen: "phone_map_test.png", cropTop: true, kicker: "MODE HORS LIGNE", title: "CARTES OFFLINE", metric: "Préparez avant le réseau faible", lead: "Téléchargez une zone compatible avant de quitter la couverture mobile.", features: [.init(title: "Téléchargement", detail: "Installez la carte utile lorsque la connexion est disponible."), .init(title: "Activation", detail: "Sélectionnez la région hors ligne depuis les outils de carte."), .init(title: "Résilience", detail: "Gardez une base cartographique quand le réseau disparaît.")], footer: "TÉLÉCHARGE • ACTIVE • EMPORTE"),
    .init(id: 6, slug: "techniques", background: "06_techniques.png", screen: "app_techniques.png", cropTop: false, kicker: "GUIDES VISUELS", title: "TECHNIQUES", metric: "18 techniques & montages", lead: "Trouvez plus vite le nœud ou le montage adapté à votre préparation.", features: [.init(title: "Recherche", detail: "Recherchez une technique par son nom."), .init(title: "Catégories", detail: "Filtrez par type de connexion ou de montage."), .init(title: "Étapes illustrées", detail: "Suivez les gestes visuellement puis testez le résultat.")], footer: "APPRENDRE • PRATIQUER • TESTER"),
    .init(id: 7, slug: "noeud_fg", background: "07_noeud_fg.png", screen: "fg.webp", cropTop: false, kicker: "NŒUD TRESSE / LEADER", title: "NŒUD FG", metric: "Connexion profilée", lead: "Un guide visuel pour relier tresse et bas de ligne avec méthode.", features: [.init(title: "Préparer", detail: "Positionnez les deux lignes sans croisement parasite."), .init(title: "Serrer progressivement", detail: "Travaillez chaque étape avant la finition."), .init(title: "Tester", detail: "Contrôlez toujours le nœud avant utilisation réelle.")], footer: "LE GUIDE EST DANS BOOSTERFISH"),
    .init(id: 8, slug: "noeud_palomar", background: "08_palomar.png", screen: "palomar.webp", cropTop: false, kicker: "NŒUD LIGNE / HAMEÇON", title: "PALOMAR", metric: "Simple à mémoriser", lead: "Visualisez le passage de la ligne et la séquence de serrage.", features: [.init(title: "Doubler la ligne", detail: "Préparez une boucle propre avant le passage dans l’œillet."), .init(title: "Former le nœud", detail: "Suivez l’ordre illustré sans pincer la ligne."), .init(title: "Contrôler", detail: "Serrez proprement et testez avant de lancer.")], footer: "UN NŒUD SE VÉRIFIE TOUJOURS"),
    .init(id: 9, slug: "preparation_jigging", background: "09_jigging.png", screen: "app_techniques.png", cropTop: false, kicker: "CHECKLIST TECHNIQUE", title: "JIGGING", metric: "Préparez le montage à quai", lead: "Contrôlez chaque point avant de descendre le jig.", features: [.init(title: "Ligne et leader", detail: "Inspectez l’usure et la connexion principale."), .init(title: "Anneaux et hameçons", detail: "Vérifiez l’ouverture, la pointe et l’assemblage."), .init(title: "Frein", detail: "Adaptez le réglage au matériel et à votre pratique.")], footer: "PRÉPARER À TERRE • PÊCHER EN MER"),
    .init(id: 10, slug: "traine_big_game", background: "10_traine_big_game.png", screen: "offshore-swivel.webp", cropTop: false, kicker: "PÊCHE HAUTURIÈRE", title: "TRAÎNE & BIG GAME", metric: "Thon • marlin • espadon", lead: "Des repères de préparation pour des montages soumis à de fortes contraintes.", features: [.init(title: "Connexion renforcée", detail: "Choisissez ligne, leader et émerillon adaptés."), .init(title: "Matériel contrôlé", detail: "Inspectez cannes, moulinets, frein et hameçons."), .init(title: "Équipe coordonnée", detail: "Répartissez les rôles et vérifiez la sécurité à bord.")], footer: "AUCUNE PRISE N’EST GARANTIE"),
    .init(id: 11, slug: "especes", background: "11_especes.png", screen: "thon rouge.png", cropTop: false, kicker: "FICHES POISSONS", title: "ESPÈCES MARINES", metric: "72 espèces répertoriées", lead: "Identifiez mieux les poissons rencontrés sur le littoral.", features: [.init(title: "Repères visuels", detail: "Comparez silhouette, nageoires et marques distinctives."), .init(title: "Conseils utiles", detail: "Retrouvez les informations présentées dans chaque fiche."), .init(title: "Réglementation", detail: "Vérifiez toujours les règles locales avant conservation.")], footer: "OBSERVER • IDENTIFIER • RESPECTER"),
    .init(id: 12, slug: "communaute", background: "12_communaute.png", screen: "home_dark_reference.png", cropTop: true, kicker: "PARTAGE ENTRE PÊCHEURS", title: "COMMUNAUTÉ", metric: "Publiez sans révéler votre spot", lead: "Partagez une expérience tout en gardant les coordonnées sensibles privées.", features: [.init(title: "Publications", detail: "Ajoutez une photo, une espèce et votre récit."), .init(title: "Interactions", detail: "Consultez les contributions et soutenez la communauté."), .init(title: "Contrôles", detail: "Signalez, bloquez ou retirez un contenu lorsque nécessaire.")], footer: "PARTAGEZ L’EXPÉRIENCE, PAS LE SECRET"),
    .init(id: 13, slug: "partage_prise", background: "13_partage_prise.png", screen: "home_dark_reference.png", cropTop: true, kicker: "VOTRE HISTOIRE", title: "PARTAGER UNE PRISE", metric: "Photo • espèce • récit", lead: "Transformez une sortie en retour d’expérience utile à la communauté.", features: [.init(title: "Photo", detail: "Choisissez une image claire et respectueuse du poisson."), .init(title: "Contexte", detail: "Ajoutez l’espèce et les informations utiles."), .init(title: "Vie privée", detail: "Ne publiez pas automatiquement votre coordonnée personnelle.")], footer: "UNE PRISE • UNE HISTOIRE • UNE COMMUNAUTÉ"),
    .init(id: 14, slug: "securite", background: "14_securite.png", screen: "home_dark_reference.png", cropTop: true, kicker: "AVANT DE PARTIR", title: "SÉCURITÉ EN MER", metric: "La préparation d’abord", lead: "Les données de l’application complètent une vraie checklist de sécurité.", features: [.init(title: "Conditions", detail: "Vérifiez vent, mer et marées avant le déplacement."), .init(title: "Équipement", detail: "Gilet, communication, eau et trousse selon la sortie."), .init(title: "Décision finale", detail: "Reportez la session si les conditions deviennent défavorables.")], footer: "L’APPLICATION NE REMPLACE PAS LA VIGILANCE"),
    .init(id: 15, slug: "magasins", background: "15_magasins.png", screen: "home_dark_reference.png", cropTop: true, kicker: "SERVICES À PROXIMITÉ", title: "MAGASINS DE PÊCHE", metric: "Le matériel près de vos spots", lead: "Repérez plus facilement un magasin utile autour de votre zone.", features: [.init(title: "Recherche locale", detail: "Parcourez les magasins associés au littoral."), .init(title: "Distance", detail: "Identifiez le magasin le plus proche d’un spot."), .init(title: "Préparation", detail: "Complétez le matériel avant de rejoindre la zone de pêche.")], footer: "TROUVEZ • PRÉPAREZ • ÉQUIPEZ-VOUS"),
    .init(id: 16, slug: "carnet_personnel", background: "16_carnet.png", screen: "current_app_screen.png", cropTop: true, kicker: "MÉMOIRE PERSONNELLE", title: "VOTRE CARNET", metric: "Retrouvez vos repères", lead: "Conservez les lieux et informations utiles d’une sortie à l’autre.", features: [.init(title: "Spots personnels", detail: "Centralisez les lieux que vous souhaitez revisiter."), .init(title: "Organisation", detail: "Ajoutez un nom, une note ou une photo selon votre besoin."), .init(title: "Confidentialité", detail: "Les coordonnées personnelles restent masquées.")], footer: "VOTRE EXPÉRIENCE VOUS APPARTIENT"),
    .init(id: 17, slug: "peche_responsable", background: "17_peche_responsable.png", screen: "thon rouge.png", cropTop: false, kicker: "RESPECT DE LA RESSOURCE", title: "PÊCHE RESPONSABLE", metric: "Préserver aujourd’hui", lead: "Mieux identifier et mieux manipuler contribue à protéger la ressource.", features: [.init(title: "Identifier", detail: "Reconnaissez l’espèce avant toute décision."), .init(title: "Manipuler avec soin", detail: "Limitez le temps hors de l’eau lorsque la remise à l’eau s’impose."), .init(title: "Respecter les règles", detail: "Contrôlez tailles, périodes et restrictions locales.")], footer: "OBSERVER • RESPECTER • PRÉSERVER"),
    .init(id: 18, slug: "test_ferme", background: "18_test_ferme.png", screen: "home_dark_reference.png", cropTop: true, kicker: "GOOGLE PLAY", title: "TEST FERMÉ", metric: "Vos retours améliorent l’app", lead: "Le test vérifie la stabilité et les parcours essentiels avant la production.", features: [.init(title: "Utiliser réellement", detail: "Testez les fonctions pendant plusieurs sessions."), .init(title: "Décrire précisément", detail: "Indiquez l’écran, l’action et le résultat observé."), .init(title: "Suivre les corrections", detail: "Installez les mises à jour distribuées aux testeurs.")], footer: "TESTER • EXPLIQUER • AMÉLIORER"),
    .init(id: 19, slug: "tout_en_un", background: "19_tout_en_un.png", screen: "home_dark_reference.png", cropTop: true, kicker: "EXPÉDITION", title: "TOUT DANS UNE APP", metric: "Carte • mer • savoir • partage", lead: "Passez de la préparation à l’apprentissage dans une expérience cohérente.", features: [.init(title: "Explorer", detail: "Spots officiels, repères privés et cartes."), .init(title: "Comprendre", detail: "Marées, conditions, espèces et techniques."), .init(title: "Partager", detail: "Communauté et publications avec contrôles intégrés.")], footer: "BOOSTERFISH • FISH • EXPLORE • SHARE"),
    .init(id: 20, slug: "bientot_disponible", background: "20_bientot.png", screen: "home_dark_reference.png", cropTop: true, kicker: "APPLICATION ANDROID", title: "BIENTÔT DISPONIBLE", metric: "Actuellement en test fermé", lead: "BoosterFish se prépare sur Google Play avec des retours de testeurs réels.", features: [.init(title: "Version testée", detail: "Les parcours principaux sont observés sur appareils réels."), .init(title: "Corrections suivies", detail: "Les incidents sont analysés avant la demande de production."), .init(title: "Lancement maîtrisé", detail: "Aucune date publique n’est annoncée avant validation.")], footer: "SUIVEZ BOOSTERFISH POUR LE LANCEMENT"),
]

let width = 1080, height = 1350
let cyan = CGColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1)
let cyanDark = CGColor(red: 0.0, green: 0.50, blue: 0.72, alpha: 1)
let navy = CGColor(red: 0.003, green: 0.018, blue: 0.052, alpha: 1)
let white = CGColor(red: 0.98, green: 0.995, blue: 1, alpha: 1)
let muted = CGColor(red: 0.76, green: 0.84, blue: 0.92, alpha: 1)

func die(_ text: String) -> Never { fputs("ERROR: \(text)\n", stderr); exit(1) }
func load(_ path: String) -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { die("Lecture impossible: \(path)") }
    return image
}
func roundRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil) }
func font(_ size: CGFloat, _ bold: Bool) -> CTFont { CTFontCreateWithName((bold ? "AvenirNext-Heavy" : "AvenirNext-Medium") as CFString, size, nil) }
func text(_ value: String, _ rect: CGRect, _ size: CGFloat, _ color: CGColor, _ bold: Bool, _ context: CGContext, spacing: CGFloat = 3) {
    let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping; style.lineSpacing = spacing
    let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font(size, bold), NSAttributedString.Key(kCTForegroundColorAttributeName as String): color, .paragraphStyle: style]
    let string = NSAttributedString(string: value, attributes: attrs)
    let setter = CTFramesetterCreateWithAttributedString(string)
    CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: string.length), CGPath(rect: rect, transform: nil), nil), context)
}
func aspectFill(_ image: CGImage, _ rect: CGRect) -> CGRect {
    let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
    let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
    return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
}
func cropTop(_ image: CGImage) -> CGImage {
    let cropHeight = Int(Double(image.height) * 0.76)
    return image.cropping(to: CGRect(x: 0, y: 0, width: image.width, height: cropHeight)) ?? image
}
func write(_ image: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { die("Création impossible: \(path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { die("Écriture impossible: \(path)") }
}

guard CommandLine.arguments.count == 8 else { die("Usage: compose_feature_posters.swift <backgrounds> <screens-root> <techniques> <fish> <logo> <output> <preview-only|all>") }
let backgrounds = CommandLine.arguments[1], root = CommandLine.arguments[2], techniques = CommandLine.arguments[3], fishes = CommandLine.arguments[4], logoPath = CommandLine.arguments[5], output = CommandLine.arguments[6], mode = CommandLine.arguments[7]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
let logo = load(logoPath)

for poster in posters where mode == "all" || poster.id == 1 {
    let bg = load("\(backgrounds)/\(String(format: "%02d", poster.id))_\(poster.background.split(separator: "_", maxSplits: 1)[1])")
    let screenPath: String
    if poster.screen.hasSuffix(".webp") { screenPath = "\(techniques)/\(poster.screen)" }
    else if poster.screen.hasSuffix(".png") && poster.screen.contains("thon") { screenPath = "\(fishes)/\(poster.screen)" }
    else if poster.screen.hasPrefix("app_") { screenPath = "\(root)/marketing/social_30_days/source_assets/\(poster.screen)" }
    else { screenPath = "\(root)/\(poster.screen)" }
    var screen = load(screenPath)
    if poster.cropTop { screen = cropTop(screen) }
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { die("Contexte indisponible") }
    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    context.draw(bg, in: aspectFill(bg, canvas))
    context.setFillColor(CGColor(red: 0.002, green: 0.014, blue: 0.045, alpha: 0.73)); context.fill(canvas)
    let horizontal = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [CGColor(red: 0.001, green: 0.015, blue: 0.055, alpha: 0.98), CGColor(red: 0.001, green: 0.015, blue: 0.055, alpha: 0.72), CGColor(red: 0.001, green: 0.015, blue: 0.055, alpha: 0.22)] as CFArray, locations: [0, 0.55, 1])!
    context.drawLinearGradient(horizontal, start: CGPoint(x: 0, y: 0), end: CGPoint(x: width, y: 0), options: [])

    // Marque.
    context.saveGState(); context.addPath(roundRect(CGRect(x: 56, y: 1210, width: 82, height: 82), 20)); context.clip(); context.draw(logo, in: CGRect(x: 56, y: 1210, width: 82, height: 82)); context.restoreGState()
    text("BOOSTER", CGRect(x: 158, y: 1235, width: 235, height: 58), 34, white, true, context)
    text("FISH", CGRect(x: 324, y: 1235, width: 110, height: 58), 34, cyan, true, context)
    text("FISH  •  EXPLORE  •  SHARE", CGRect(x: 159, y: 1206, width: 320, height: 28), 13, muted, true, context)
    text(String(format: "%02d / 20", poster.id), CGRect(x: 865, y: 1240, width: 145, height: 36), 23, cyan, true, context)

    // Colonne éditoriale.
    text(poster.kicker, CGRect(x: 58, y: 1126, width: 520, height: 34), 18, cyan, true, context)
    text(poster.title, CGRect(x: 56, y: 998, width: 540, height: 120), poster.title.count > 18 ? 39 : 49, white, true, context)
    text(poster.metric, CGRect(x: 57, y: 936, width: 540, height: 45), 28, cyan, true, context)
    text(poster.lead, CGRect(x: 58, y: 846, width: 520, height: 78), 20, muted, false, context, spacing: 5)

    for (index, feature) in poster.features.enumerated() {
        let y = CGFloat(690 - index * 174)
        let rect = CGRect(x: 56, y: y, width: 526, height: 146)
        context.addPath(roundRect(rect, 26)); context.setFillColor(CGColor(red: 0.01, green: 0.055, blue: 0.13, alpha: 0.90)); context.fillPath()
        context.setStrokeColor(CGColor(red: 0.0, green: 0.72, blue: 0.95, alpha: 0.75)); context.setLineWidth(2); context.addPath(roundRect(rect, 26)); context.strokePath()
        context.setFillColor(cyanDark); context.addEllipse(in: CGRect(x: 76, y: y + 78, width: 50, height: 50)); context.fillPath()
        text(String(format: "%02d", index + 1), CGRect(x: 87, y: y + 92, width: 34, height: 25), 17, white, true, context)
        text(feature.title, CGRect(x: 145, y: y + 86, width: 405, height: 32), 23, white, true, context)
        text(feature.detail, CGRect(x: 145, y: y + 28, width: 405, height: 54), 17, muted, false, context, spacing: 3)
    }

    // Téléphone réel, avec halo cyan et écran BoosterFish.
    let phone = CGRect(x: 620, y: 244, width: 400, height: 856)
    for halo in stride(from: 16, through: 4, by: -4) {
        context.setStrokeColor(CGColor(red: 0, green: 0.75, blue: 1, alpha: CGFloat(18 - halo) / 90 + 0.05)); context.setLineWidth(CGFloat(halo)); context.addPath(roundRect(phone, 58)); context.strokePath()
    }
    context.addPath(roundRect(phone, 58)); context.setFillColor(navy); context.fillPath(); context.setStrokeColor(cyan); context.setLineWidth(5); context.addPath(roundRect(phone, 58)); context.strokePath()
    let display = CGRect(x: 640, y: 270, width: 360, height: 802)
    context.saveGState(); context.addPath(roundRect(display, 40)); context.clip(); context.draw(screen, in: aspectFill(screen, display)); context.restoreGState()
    context.addPath(roundRect(CGRect(x: 770, y: 1046, width: 100, height: 20), 10)); context.setFillColor(CGColor(gray: 0.02, alpha: 1)); context.fillPath()
    context.setFillColor(CGColor(red: 0.02, green: 0.80, blue: 1, alpha: 1)); context.addEllipse(in: CGRect(x: 810, y: 256, width: 18, height: 18)); context.fillPath()

    // Pied de page.
    context.addPath(roundRect(CGRect(x: 56, y: 56, width: 964, height: 90), 30)); context.setFillColor(CGColor(red: 0.002, green: 0.025, blue: 0.08, alpha: 0.92)); context.fillPath(); context.setStrokeColor(CGColor(red: 0, green: 0.72, blue: 0.95, alpha: 0.58)); context.setLineWidth(2); context.addPath(roundRect(CGRect(x: 56, y: 56, width: 964, height: 90), 30)); context.strokePath()
    text(poster.footer, CGRect(x: 88, y: 86, width: 820, height: 34), 18, white, true, context)
    text("●", CGRect(x: 942, y: 83, width: 30, height: 34), 22, cyan, true, context)

    guard let final = context.makeImage() else { die("Image finale indisponible") }
    write(final, "\(output)/\(String(format: "%02d", poster.id))_\(poster.slug).png")
    print("OK \(String(format: "%02d", poster.id))_\(poster.slug).png")
}

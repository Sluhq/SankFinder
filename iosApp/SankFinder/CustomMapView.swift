import SwiftUI
import MapKit
import UIKit

// MARK: - OpenStreetMap Mapnik Ploščice s predpomnjenjem in Over-Zoom podporo (brez Apple Maps)
class OSMTileOverlay: MKTileOverlay {
    private let tileCache = NSCache<NSString, NSData>()
    private let maxNativeZ: Int = 19
    
    private static let tileSession: URLSession = {
        let config = URLSessionConfiguration.default
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("OSMTileDiskCache", isDirectory: true)
        config.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,   // 64 MB RAM
            diskCapacity: 256 * 1024 * 1024,    // 256 MB Disk
            directory: cacheDir
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()
    
    init() {
        super.init(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        // Izklopi Apple Maps podlago v ozadju
        self.canReplaceMapContent = true
        self.tileSize = CGSize(width: 256, height: 256)
        // Dovolimo zum do z = 22 (nad z = 19 se izreže in poveča ploščica iz z = 19)
        self.maximumZ = 22
        self.minimumZ = 1
        tileCache.countLimit = 1500
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        return URL(string: "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
    }
    
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let key = "\(path.z)/\(path.x)/\(path.y)" as NSString
        if let cached = tileCache.object(forKey: key) {
            result(cached as Data, nil)
            return
        }
        
        // 1. Over-Zoom: če je z > 19, izreži in povečaj ustrezni del ploščice iz z = 19
        if path.z > maxNativeZ {
            let diff = path.z - maxNativeZ
            let parentX = path.x >> diff
            let parentY = path.y >> diff
            let parentPath = MKTileOverlayPath(
                x: parentX,
                y: parentY,
                z: maxNativeZ,
                contentScaleFactor: path.contentScaleFactor
            )
            
            fetchNativeTile(at: parentPath) { [weak self] parentData, error in
                guard let self = self,
                      let parentData = parentData,
                      let upscaled = self.cropAndUpscaleTile(parentData: parentData, childX: path.x, childY: path.y, diff: diff) else {
                    DispatchQueue.main.async { result(nil, error) }
                    return
                }
                self.tileCache.setObject(upscaled as NSData, forKey: key)
                DispatchQueue.main.async { result(upscaled, nil) }
            }
            return
        }
        
        // 2. Standardni prenos izvorne OSM ploščice (z <= 19)
        fetchNativeTile(at: path) { [weak self] data, error in
            if let data = data {
                DispatchQueue.main.async { result(data, nil) }
            } else if let fallback = self?.tryFallbackFromCachedParent(for: path) {
                DispatchQueue.main.async { result(fallback, nil) }
            } else {
                DispatchQueue.main.async { result(nil, error) }
            }
        }
    }
    
    private func fetchNativeTile(at path: MKTileOverlayPath, completion: @escaping (Data?, Error?) -> Void) {
        let key = "\(path.z)/\(path.x)/\(path.y)" as NSString
        if let cached = tileCache.object(forKey: key) {
            completion(cached as Data, nil)
            return
        }
        
        let tileUrl = self.url(forTilePath: path)
        var request = URLRequest(url: tileUrl)
        request.setValue("SankFinderApp-Slovenia/1.2 (https://sankfinder.sluga.me; contact@sluga.me)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        
        Self.tileSession.dataTask(with: request) { [weak self] data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                completion(nil, error)
                return
            }
            guard let data = data, !data.isEmpty, UIImage(data: data) != nil else {
                completion(nil, error)
                return
            }
            self?.tileCache.setObject(data as NSData, forKey: key)
            completion(data, nil)
        }.resume()
    }
    
    private func cropAndUpscaleTile(parentData: Data, childX: Int, childY: Int, diff: Int) -> Data? {
        guard diff > 0,
              let image = UIImage(data: parentData),
              let cgImage = image.cgImage else { return nil }
        
        let scale = 1 << diff
        let subX = childX % scale
        let subY = childY % scale
        
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let cropW = imgW / CGFloat(scale)
        let cropH = imgH / CGFloat(scale)
        
        let cropRect = CGRect(
            x: CGFloat(subX) * cropW,
            y: CGFloat(subY) * cropH,
            width: cropW,
            height: cropH
        )
        
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format)
        let upscaledImage = renderer.image { _ in
            UIImage(cgImage: croppedCG).draw(in: CGRect(x: 0, y: 0, width: 256, height: 256))
        }
        return upscaledImage.pngData()
    }
    
    private func tryFallbackFromCachedParent(for path: MKTileOverlayPath) -> Data? {
        for diff in 1...2 {
            let parentZ = path.z - diff
            guard parentZ >= minimumZ else { continue }
            let parentKey = "\(parentZ)/\(path.x >> diff)/\(path.y >> diff)" as NSString
            if let parentData = tileCache.object(forKey: parentKey) as Data?,
               let upscaled = cropAndUpscaleTile(parentData: parentData, childX: path.x, childY: path.y, diff: diff) {
                return upscaled
            }
        }
        return nil
    }
}

// MARK: - Označevalec lokala (čista zelena pika brez emojijev)
class LokalAnnotation: NSObject, MKAnnotation {
    let lokal: Lokal
    var coordinate: CLLocationCoordinate2D { lokal.coordinate }
    var title: String? { lokal.name }
    var subtitle: String? { lokal.address }
    
    init(lokal: Lokal) {
        self.lokal = lokal
        super.init()
    }
}

// MARK: - Pogled za zeleno piko šanka (Popolnoma brez emojijev in brez združevanja v grozde)
class PubDotAnnotationView: MKAnnotationView {
    private let dotView = UIView()
    private let innerDot = UIView()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        self.canShowCallout = false
        self.clusteringIdentifier = nil
        self.displayPriority = .defaultHigh
        
        self.frame = CGRect(x: 0, y: 0, width: 26, height: 26)
        self.centerOffset = CGPoint(x: 0, y: 0)
        
        // Glavni zeleni krog (#43A047 - svetlo zelena kot na Androidu)
        dotView.frame = CGRect(x: 1, y: 1, width: 24, height: 24)
        dotView.backgroundColor = UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0)
        dotView.layer.cornerRadius = 12
        dotView.layer.borderWidth = 2.5
        dotView.layer.borderColor = UIColor.white.cgColor
        dotView.layer.shadowColor = UIColor.black.cgColor
        dotView.layer.shadowOpacity = 0.35
        dotView.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        dotView.layer.shadowRadius = 2.5
        addSubview(dotView)
        
        // Notranja bela pika za natančnost (kot na Androidu)
        innerDot.frame = CGRect(x: 9, y: 9, width: 6, height: 6)
        innerDot.backgroundColor = UIColor.white
        innerDot.layer.cornerRadius = 3
        addSubview(innerDot)
    }
    
    func setSelectedState(_ isSelected: Bool) {
        UIView.animate(withDuration: 0.15) {
            if isSelected {
                self.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                self.dotView.backgroundColor = UIColor(red: 46/255, green: 125/255, blue: 50/255, alpha: 1.0) // Temno zelena ob izbiri (#2E7D32)
                self.innerDot.backgroundColor = UIColor(red: 255/255, green: 213/255, blue: 79/255, alpha: 1.0) // Zlata pika (#FFD54F)
            } else {
                self.transform = .identity
                self.dotView.backgroundColor = UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0) // Svetlo zelena kot na Androidu (#43A047)
                self.innerDot.backgroundColor = UIColor.white
            }
        }
    }
}

// MARK: - Označevalec prijatelja iz Pivske Klape (z imenom in številom pijač)
class SquadFriendAnnotation: NSObject, MKAnnotation {
    let member: SquadMember
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: member.lat ?? 46.0569, longitude: member.lon ?? 14.5058)
    }
    var title: String? { "\(member.name) (\(member.drinksCount) pijač)" }
    var subtitle: String? { "Pivska Klapa • v živo" }
    
    init(member: SquadMember) {
        self.member = member
        super.init()
    }
}

// MARK: - Pogled označevalca prijatelja (Zlati krog z začetnico, značko pijač in imenom - NIKOLI se ne združi v grozd)
class SquadFriendAnnotationView: MKAnnotationView {
    private let circleView = UIView()
    private let initialLabel = UILabel()
    private let drinksBadge = UIView()
    private let drinksLabel = UILabel()
    private let nameLabel = UILabel()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        self.canShowCallout = true
        self.clusteringIdentifier = nil
        self.displayPriority = .required // Ključno: MapKit NIKOLI ne skrije ali združi prijatelja pri zoomiranju!
        
        self.frame = CGRect(x: 0, y: 0, width: 44, height: 50)
        self.centerOffset = CGPoint(x: 0, y: -20)
        
        // Zlati krog
        circleView.frame = CGRect(x: 6, y: 4, width: 32, height: 32)
        circleView.backgroundColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
        circleView.layer.cornerRadius = 16
        circleView.layer.borderWidth = 2.5
        circleView.layer.borderColor = UIColor.white.cgColor
        circleView.layer.shadowColor = UIColor.black.cgColor
        circleView.layer.shadowOpacity = 0.35
        circleView.layer.shadowOffset = CGSize(width: 0, height: 2)
        circleView.layer.shadowRadius = 3
        addSubview(circleView)
        
        // Začetnica
        initialLabel.frame = circleView.bounds
        initialLabel.textAlignment = .center
        initialLabel.font = UIFont.systemFont(ofSize: 15, weight: .black)
        initialLabel.textColor = UIColor.black
        circleView.addSubview(initialLabel)
        
        // Značka s številom pijač (zgoraj desno)
        drinksBadge.frame = CGRect(x: 26, y: 0, width: 18, height: 16)
        drinksBadge.backgroundColor = UIColor(red: 18/255, green: 24/255, blue: 38/255, alpha: 0.95)
        drinksBadge.layer.cornerRadius = 8
        drinksBadge.layer.borderWidth = 1.0
        drinksBadge.layer.borderColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0).cgColor
        addSubview(drinksBadge)
        
        drinksLabel.frame = drinksBadge.bounds
        drinksLabel.textAlignment = .center
        drinksLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        drinksLabel.textColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
        drinksBadge.addSubview(drinksLabel)
        
        // Spodnje ime prijatelja
        nameLabel.frame = CGRect(x: -18, y: 38, width: 80, height: 14)
        nameLabel.textAlignment = .center
        nameLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        nameLabel.textColor = UIColor.white
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOpacity = 0.85
        nameLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        nameLabel.layer.shadowRadius = 2
        addSubview(nameLabel)
    }
    
    func configure(with member: SquadMember) {
        initialLabel.text = String(member.name.prefix(1)).uppercased()
        drinksLabel.text = "\(member.drinksCount)"
        nameLabel.text = member.name
    }
}

// MARK: - Pogled lokacije uporabnika (MODRA PIKA #1A73E8 z modro smerno puščico kot Google Maps / Apple Maps)
class UserHeadingAnnotationView: MKAnnotationView {
    private let containerView = UIView()
    private let arrowLayer = CAShapeLayer()
    private let dotView = UIView()
    private let innerDot = UIView()
    
    // Električno modra barva za uporabnika (#1A73E8)
    private let userBlue = UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0)
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        self.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        self.centerOffset = CGPoint(x: 0, y: 0)
        self.canShowCallout = false
        self.clusteringIdentifier = nil
        self.displayPriority = .required
        
        containerView.frame = self.bounds
        addSubview(containerView)
        
        // 1. Modra smerna puščica z belim robom
        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: 22, y: 1))
        arrowPath.addLine(to: CGPoint(x: 14, y: 15))
        arrowPath.addLine(to: CGPoint(x: 30, y: 15))
        arrowPath.close()
        
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.fillColor = userBlue.cgColor
        arrowLayer.strokeColor = UIColor.white.cgColor
        arrowLayer.lineWidth = 1.8
        containerView.layer.addSublayer(arrowLayer)
        
        // 2. Glavni modri krog z belo obrobo (#1A73E8)
        dotView.frame = CGRect(x: 11, y: 11, width: 22, height: 22)
        dotView.backgroundColor = userBlue
        dotView.layer.cornerRadius = 11
        dotView.layer.borderWidth = 3.0
        dotView.layer.borderColor = UIColor.white.cgColor
        dotView.layer.shadowColor = UIColor.black.cgColor
        dotView.layer.shadowOpacity = 0.45
        dotView.layer.shadowOffset = CGSize(width: 0, height: 2)
        dotView.layer.shadowRadius = 4
        containerView.addSubview(dotView)
        
        // 3. Notranja bela pika
        innerDot.frame = CGRect(x: 19, y: 19, width: 6, height: 6)
        innerDot.backgroundColor = UIColor.white
        innerDot.layer.cornerRadius = 3
        containerView.addSubview(innerDot)
    }
    
    private var currentAngleDeg: Double = 0.0
    private var hasSetInitialAngle: Bool = false

    func updateHeading(_ heading: Double, mapHeading: Double = 0.0) {
        let targetDeg = heading - mapHeading
        
        if !hasSetInitialAngle {
            hasSetInitialAngle = true
            currentAngleDeg = targetDeg
            let rad = CGFloat(currentAngleDeg * .pi / 180.0)
            self.containerView.transform = CGAffineTransform(rotationAngle: rad)
            return
        }
        
        // Izracunaj najkrajso kotno razliko med trenutnim in novim kotom (med -180 in +180)
        var diff = (targetDeg - currentAngleDeg).truncatingRemainder(dividingBy: 360.0)
        if diff > 180.0 { diff -= 360.0 }
        if diff < -180.0 { diff += 360.0 }
        
        // Mrtva cona: ignoriraj mikrotresljaje kompasa pod 1.5 stopinje
        if abs(diff) < 1.5 { return }
        
        currentAngleDeg += diff
        let radians = CGFloat(currentAngleDeg * .pi / 180.0)
        
        UIView.animate(withDuration: 0.16, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            self.containerView.transform = CGAffineTransform(rotationAngle: radians)
        }, completion: nil)
    }
}

// MARK: - Izris dinamične ukrivljene navigacijske puščice na cestišču (100% identično Androidu)
func createDynamicTurnArrowImage(turnAngleDeg: CGFloat) -> UIImage {
    let size: CGFloat = 80.0
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.image { ctx in
        let cgCtx = ctx.cgContext
        let cx = size / 2.0
        let cy = size / 2.0
        let d: CGFloat = 1.15
        
        // Omeji kot zavoja med -155° in +155° za naraven izgled
        let angle = min(max(turnAngleDeg, -155.0), 155.0)
        let rad = angle * .pi / 180.0
        let dirX = sin(rad)
        let dirY = -cos(rad)
        
        let stemLen = 20.0 * d
        let outLen = 22.0 * d
        
        let startX = cx
        let startY = cy + stemLen
        let shaftEndX = cx + dirX * outLen
        let shaftEndY = cy + dirY * outLen
        
        // 1. Pot stebla puščice
        let shaftPath = UIBezierPath()
        shaftPath.move(to: CGPoint(x: startX, y: startY))
        if abs(angle) < 14.0 {
            shaftPath.addLine(to: CGPoint(x: shaftEndX, y: shaftEndY))
        } else {
            shaftPath.addLine(to: CGPoint(x: cx, y: cy + 5.0 * d))
            shaftPath.addQuadCurve(to: CGPoint(x: shaftEndX, y: shaftEndY), controlPoint: CGPoint(x: cx, y: cy - 2.0 * d))
        }
        
        // 2. Glava puščice (konica in krilca)
        let headLen = 13.0 * d
        let headHalfWidth = 9.5 * d
        let tipX = shaftEndX + dirX * (5.5 * d)
        let tipY = shaftEndY + dirY * (5.5 * d)
        let normX = -dirY
        let normY = dirX
        
        let wing1X = shaftEndX - dirX * (headLen * 0.65) + normX * headHalfWidth
        let wing1Y = shaftEndY - dirY * (headLen * 0.65) + normY * headHalfWidth
        let wing2X = shaftEndX - dirX * (headLen * 0.65) - normX * headHalfWidth
        let wing2Y = shaftEndY - dirY * (headLen * 0.65) - normY * headHalfWidth
        let notchX = shaftEndX - dirX * (headLen * 0.3)
        let notchY = shaftEndY - dirY * (headLen * 0.3)
        
        let headPath = UIBezierPath()
        headPath.move(to: CGPoint(x: tipX, y: tipY))
        headPath.addLine(to: CGPoint(x: wing1X, y: wing1Y))
        headPath.addLine(to: CGPoint(x: notchX, y: notchY))
        headPath.addLine(to: CGPoint(x: wing2X, y: wing2Y))
        headPath.close()
        
        // 1. Zunanja senca za globino
        cgCtx.saveGState()
        cgCtx.translateBy(x: 0, y: 1.8 * d)
        let shadowColor = UIColor.black.withAlphaComponent(0.28)
        cgCtx.setStrokeColor(shadowColor.cgColor)
        cgCtx.setFillColor(shadowColor.cgColor)
        cgCtx.setLineWidth(16.0 * d)
        cgCtx.setLineCap(.round)
        cgCtx.setLineJoin(.round)
        cgCtx.addPath(shaftPath.cgPath)
        cgCtx.strokePath()
        cgCtx.addPath(headPath.cgPath)
        cgCtx.fillPath()
        cgCtx.restoreGState()
        
        // 2. Krepek beli rob (casing), ki se natanko ujema z robom poti
        cgCtx.saveGState()
        cgCtx.setStrokeColor(UIColor.white.cgColor)
        cgCtx.setFillColor(UIColor.white.cgColor)
        cgCtx.setLineWidth(14.0 * d)
        cgCtx.setLineCap(.round)
        cgCtx.setLineJoin(.round)
        cgCtx.addPath(shaftPath.cgPath)
        cgCtx.strokePath()
        cgCtx.addPath(headPath.cgPath)
        cgCtx.fillPath()
        cgCtx.setLineWidth(3.0 * d)
        cgCtx.addPath(headPath.cgPath)
        cgCtx.strokePath()
        cgCtx.restoreGState()
        
        // 3. Notranje smaragdno zeleno jedro (#0F9D58, barva navigacijske poti)
        cgCtx.saveGState()
        let emeraldGreen = UIColor(red: 15/255, green: 157/255, blue: 88/255, alpha: 1.0)
        cgCtx.setStrokeColor(emeraldGreen.cgColor)
        cgCtx.setFillColor(emeraldGreen.cgColor)
        cgCtx.setLineWidth(8.0 * d)
        cgCtx.setLineCap(.round)
        cgCtx.setLineJoin(.round)
        cgCtx.addPath(shaftPath.cgPath)
        cgCtx.strokePath()
        cgCtx.addPath(headPath.cgPath)
        cgCtx.fillPath()
        cgCtx.restoreGState()
    }
}

// MARK: - Označevalec za dinamično puščico zavoja na cestišču
class CurvedManeuverAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let incomingBearing: Double
    let turnAngle: Double
    let arrowImage: UIImage
    
    init(coordinate: CLLocationCoordinate2D, incomingBearing: Double, turnAngle: Double, arrowImage: UIImage) {
        self.coordinate = coordinate
        self.incomingBearing = incomingBearing
        self.turnAngle = turnAngle
        self.arrowImage = arrowImage
        super.init()
    }
}

// MARK: - Pogled za ukrivljeno navigacijsko puščico (ravno na cestišču, poravnana s smerjo vožnje)
class CurvedManeuverAnnotationView: MKAnnotationView {
    private let arrowImageView = UIImageView()
    var incomingBearing: Double = 0.0
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        self.canShowCallout = false
        self.clusteringIdentifier = nil
        self.displayPriority = .required
        self.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        self.centerOffset = CGPoint(x: 0, y: 0)
        
        arrowImageView.frame = self.bounds
        arrowImageView.contentMode = .center
        addSubview(arrowImageView)
    }
    
    func configure(with annot: CurvedManeuverAnnotation, mapHeading: Double) {
        self.incomingBearing = annot.incomingBearing
        self.arrowImageView.image = annot.arrowImage
        updateRotation(mapHeading: mapHeading)
    }
    
    func updateRotation(mapHeading: Double) {
        // Zasukaj natanko vzdolž smeri ceste glede na trenutni kot karte
        let angleRad = CGFloat((incomingBearing - mapHeading) * .pi / 180.0)
        self.transform = CGAffineTransform(rotationAngle: angleRad)
    }
}

// MARK: - Dvoslojni Polyline Renderer (Beli spodnji casing + krepka zelena #0F9D58 linija zgoraj)
class NavigationRoutePolylineRenderer: MKPolylineRenderer {
    override func createPath() {
        super.createPath()
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if self.path == nil {
            self.createPath()
        }
        guard let path = self.path else { return }
        
        // 1. Spodnji beli rob (casing - širina 11pt)
        context.saveGState()
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(11.0 / zoomScale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
        
        // 2. Glavna navigacijska linija (#0F9D58 zelena kot na Androidu - širina 7pt)
        context.saveGState()
        let greenColor = UIColor(red: 15/255, green: 157/255, blue: 88/255, alpha: 1.0)
        context.setStrokeColor(greenColor.cgColor)
        context.setLineWidth(7.0 / zoomScale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }
}

// MARK: - Glavni SwiftUI CustomMapView
struct CustomMapView: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D?
    var centerTrigger: UUID = UUID()
    var userHeading: Double = 0.0
    @Binding var mapHeading: Double
    var resetHeadingTrigger: UUID = UUID()
    var bars: [Lokal]
    var squadMembers: [SquadMember] = []
    var selectedLokal: Lokal?
    var routeCoordinates: [CLLocationCoordinate2D]
    var routeSteps: [OsrmStep] = []
    var currentStepIndex: Int = 0
    var isNavigating: Bool = false
    @Binding var isFollowingUser: Bool
    var userLocation: CLLocationCoordinate2D? = nil
    var targetBearing: Double? = nil
    var onSelectLokal: (Lokal) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Zaznaj ročni dotik / premik karte za izklop samodejnega sledenja
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)
        
        // Prepreči prikaz nezaželenih Apple ikon in stavb
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        
        // Omejimo zum na razdaljo, kjer so OpenStreetMap ploščice vedno prisotne (do z=19),
        // s čimer se prepreči preklop na Apple Maps (slika 2)
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 85.0,
            maxCenterCoordinateDistance: 2_000_000.0
        )
        
        // OpenStreetMap ploščice dodamo na .aboveRoads,
        // navigacijska trasa pa bo dodana na .aboveLabels in se NIKOLI ne izgubi ali prekrije!
        let osmOverlay = OSMTileOverlay()
        mapView.addOverlay(osmOverlay, level: .aboveRoads)
        
        let startCoord = centerCoordinate ?? LocationManager.defaultCoordinate
        let region = MKCoordinateRegion(center: startCoord, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015))
        mapView.setRegion(region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self
        // Puščica uporabnika vedno dinamično kaže v smer zasuka telefona glede na trenutno orientacijo zemljevida
        if let userView = context.coordinator.currentUserView {
            userView.updateHeading(userHeading, mapHeading: uiView.camera.heading)
        } else if let userAnnot = uiView.userLocation as MKAnnotation?, let view = uiView.view(for: userAnnot) as? UserHeadingAnnotationView {
            context.coordinator.currentUserView = view
            view.updateHeading(userHeading, mapHeading: uiView.camera.heading)
        }
        
        // 1. Upravljanje navigacijske kamere (Sledenje uporabniku v smeri HOJE - stabilno vzdolž ulice brez tresenja)
        if isNavigating {
            if !context.coordinator.wasNavigating {
                // Začetek navigacije: usmeri kamero v smer začetka poti
                context.coordinator.wasNavigating = true
                context.coordinator.wasFollowingUser = true
                
                let center = userLocation ?? centerCoordinate ?? LocationManager.defaultCoordinate
                let initialBearing: Double
                if let target = targetBearing {
                    initialBearing = target
                } else if let walkingBearing = calculateRouteWalkingBearing(userLoc: center, routeCoords: routeCoordinates) {
                    initialBearing = walkingBearing
                } else if routeCoordinates.count >= 2 {
                    initialBearing = calculateBearing(from: routeCoordinates[0], to: routeCoordinates[1])
                } else {
                    initialBearing = 0.0
                }
                
                let navCamera = MKMapCamera(
                    lookingAtCenter: center,
                    fromDistance: 320.0,
                    pitch: 0.0,
                    heading: initialBearing
                )
                uiView.setCamera(navCamera, animated: true)
            } else if isFollowingUser, let userCoord = userLocation {
                // Med aktivno hojo: kamera zvezno sledi uporabniku v središču in je STABILNO usmerjena v smer hoje vzdolž ulice
                let targetHeading: Double
                if let target = targetBearing {
                    targetHeading = target
                } else if let walkingBearing = calculateRouteWalkingBearing(userLoc: userCoord, routeCoords: routeCoordinates) {
                    targetHeading = walkingBearing
                } else if routeCoordinates.count >= 2 {
                    targetHeading = calculateBearing(from: routeCoordinates[0], to: routeCoordinates[1])
                } else {
                    targetHeading = uiView.camera.heading
                }
                
                let curCam = uiView.camera
                let dist = distanceBetween(curCam.centerCoordinate, userCoord)
                let hDiff = abs(curCam.heading - targetHeading)
                let becameFollowing = (!context.coordinator.wasFollowingUser && isFollowingUser)
                
                // Posodobi kamero le ob dejanskem premiku ali zavoju na novo ulico (prepreči nihanje)
                if dist > 2.0 || hDiff > 4.0 || becameFollowing {
                    let followCam = MKMapCamera(
                        lookingAtCenter: userCoord,
                        fromDistance: 320.0,
                        pitch: 0.0,
                        heading: targetHeading
                    )
                    uiView.setCamera(followCam, animated: true)
                }
                context.coordinator.wasFollowingUser = isFollowingUser
            } else {
                context.coordinator.wasFollowingUser = isFollowingUser
            }
        } else {
            if context.coordinator.wasNavigating {
                // Zaključek navigacije -> poravnaj nazaj na sever in vrni privzeti pregled
                context.coordinator.wasNavigating = false
                context.coordinator.wasFollowingUser = false
                let curCam = uiView.camera
                let resetCam = MKMapCamera(
                    lookingAtCenter: curCam.centerCoordinate,
                    fromDistance: 1200.0,
                    pitch: 0.0,
                    heading: 0.0
                )
                uiView.setCamera(resetCam, animated: true)
            }
            
            // Standardno osredotočenje kamere ob klicu centerTrigger ali spremembi centerCoordinate
            if context.coordinator.lastCenterTrigger != centerTrigger, let center = centerCoordinate {
                context.coordinator.lastCenterTrigger = centerTrigger
                context.coordinator.lastCenteredId = "\(center.latitude),\(center.longitude)"
                let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
                uiView.setRegion(region, animated: true)
            } else if let center = centerCoordinate, context.coordinator.lastCenteredId != "\(center.latitude),\(center.longitude)" {
                context.coordinator.lastCenteredId = "\(center.latitude),\(center.longitude)"
                let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
                uiView.setRegion(region, animated: true)
            }
        }
        
        // Ponastavitev orientacije na sever (kompas gumb)
        if context.coordinator.lastResetHeadingTrigger != resetHeadingTrigger {
            context.coordinator.lastResetHeadingTrigger = resetHeadingTrigger
            let cam = uiView.camera
            let newCam = MKMapCamera(lookingAtCenter: cam.centerCoordinate, fromDistance: cam.centerCoordinateDistance, pitch: cam.pitch, heading: 0)
            uiView.setCamera(newCam, animated: true)
        }
        
        // 2. Posodobitev navigacijske rute (posodobi se LE ob dejanski spremembi tock rute)
        let routeSig = routeCoordinates.isEmpty ? "" : "\(routeCoordinates.count)_\(routeCoordinates.first?.latitude ?? 0)_\(routeCoordinates.last?.latitude ?? 0)"
        if context.coordinator.lastRouteSignature != routeSig {
            context.coordinator.lastRouteSignature = routeSig
            let currentPolylines = uiView.overlays.compactMap { $0 as? MKPolyline }
            uiView.removeOverlays(currentPolylines)
            
            if !routeCoordinates.isEmpty {
                let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
                // Polyline dodamo na .aboveLabels, da je vedno nad ploscicami
                uiView.addOverlay(polyline, level: .aboveLabels)
                
                // Predogled celotne trase SAMO pred zacetkom aktivne navigacije
                if !isNavigating && context.coordinator.lastRouteCount != routeCoordinates.count {
                    context.coordinator.lastRouteCount = routeCoordinates.count
                    let edgeInsets = UIEdgeInsets(top: 100, left: 60, bottom: 200, right: 60)
                    uiView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: edgeInsets, animated: true)
                }
                
                uiView.selectedAnnotations = []
            } else {
                context.coordinator.lastRouteCount = 0
            }
        }
        
        // 2.1 Posodobitev dinamicne UKRIVLJENE navigacijske puscice na cestiscu za prihajajoci zavoj
        // Puscico osvezimo SAMO ko se zamenja korak ali ruta, ne pa na vsak premik kompasa (prepreci utripanje)
        if !routeCoordinates.isEmpty && !routeSteps.isEmpty && isNavigating {
            let upcomingIdx = (currentStepIndex + 1 < routeSteps.count) ? (currentStepIndex + 1) : (routeSteps.count - 1)
            let step = routeSteps[upcomingIdx]
            let isArrive = step.maneuver?.type?.lowercased() == "arrive"
            
            if !isArrive, let loc = step.maneuver?.location, loc.count >= 2 {
                let stepKey = "\(upcomingIdx)_\(loc[0])_\(loc[1])"
                
                if context.coordinator.currentManeuverStepKey != stepKey {
                    context.coordinator.currentManeuverStepKey = stepKey
                    
                    if let oldAnnot = context.coordinator.currentManeuverAnnotation {
                        uiView.removeAnnotation(oldAnnot)
                        context.coordinator.currentManeuverAnnotation = nil
                    }
                    
                    let geo = CLLocationCoordinate2D(latitude: loc[1], longitude: loc[0])
                    var bestIdx = -1
                    var minDist = Double.greatestFiniteMagnitude
                    for (i, pt) in routeCoordinates.enumerated() {
                        let d = distanceBetween(pt, geo)
                        if d < minDist {
                            minDist = d
                            bestIdx = i
                        }
                    }
                    
                    let bIn: Double
                    let bOut: Double
                    if bestIdx != -1 && routeCoordinates.count >= 2 {
                        let pBefore = bestIdx > 0 ? routeCoordinates[bestIdx - 1] : routeCoordinates[0]
                        let pAfter = bestIdx < routeCoordinates.count - 1 ? routeCoordinates[bestIdx + 1] : routeCoordinates.last!
                        let rawIn = calculateBearing(from: pBefore, to: geo)
                        let rawOut = calculateBearing(from: geo, to: pAfter)
                        bIn = (pBefore.latitude != geo.latitude || pBefore.longitude != geo.longitude) ? rawIn : (step.maneuver?.bearingBefore ?? 0.0)
                        bOut = (geo.latitude != pAfter.latitude || geo.longitude != pAfter.longitude) ? rawOut : (step.maneuver?.bearingAfter ?? 0.0)
                    } else {
                        bIn = step.maneuver?.bearingBefore ?? 0.0
                        bOut = step.maneuver?.bearingAfter ?? 0.0
                    }
                    
                    let rawTurn = ((bOut - bIn + 540.0).truncatingRemainder(dividingBy: 360.0)) - 180.0
                    let arrowImg = createDynamicTurnArrowImage(turnAngleDeg: CGFloat(rawTurn))
                    let annot = CurvedManeuverAnnotation(
                        coordinate: geo,
                        incomingBearing: bIn,
                        turnAngle: rawTurn,
                        arrowImage: arrowImg
                    )
                    context.coordinator.currentManeuverAnnotation = annot
                    uiView.addAnnotation(annot)
                }
            } else {
                if let oldAnnot = context.coordinator.currentManeuverAnnotation {
                    uiView.removeAnnotation(oldAnnot)
                    context.coordinator.currentManeuverAnnotation = nil
                }
                context.coordinator.currentManeuverStepKey = nil
            }
        } else {
            if let oldAnnot = context.coordinator.currentManeuverAnnotation {
                uiView.removeAnnotation(oldAnnot)
                context.coordinator.currentManeuverAnnotation = nil
            }
            context.coordinator.currentManeuverStepKey = nil
        }
        
        // 3. Posodobitev lokalov (zelene pike)
        let existingLokalAnnotations = uiView.annotations.compactMap { $0 as? LokalAnnotation }
        let existingBarIds = Set(existingLokalAnnotations.map { $0.lokal.id })
        let newBarIds = Set(bars.map { $0.id })
        
        if existingBarIds != newBarIds {
            uiView.removeAnnotations(existingLokalAnnotations)
            let newAnnotations = bars.map { LokalAnnotation(lokal: $0) }
            uiView.addAnnotations(newAnnotations)
        }
        
        // 3.1 Posodobitev stanja izbire označevalcev (ko se zapre ali zamenja lokal)
        for annot in uiView.annotations {
            if let lokalAnnot = annot as? LokalAnnotation,
               let dotView = uiView.view(for: lokalAnnot) as? PubDotAnnotationView {
                let isSelected = (selectedLokal != nil && selectedLokal?.id == lokalAnnot.lokal.id)
                dotView.setSelectedState(isSelected)
            }
        }
        
        // 4. Posodobitev prijateljev iz Pivske Klape (z zaznavo premikov in števila pijač)
        let validMembers = squadMembers.filter { $0.lat != nil && $0.lon != nil }
        let existingSquadAnnotations = uiView.annotations.compactMap { $0 as? SquadFriendAnnotation }
        
        var squadChanged = existingSquadAnnotations.count != validMembers.count
        if !squadChanged {
            for m in validMembers {
                if let existing = existingSquadAnnotations.first(where: { $0.member.id == m.id }) {
                    if existing.coordinate.latitude != (m.lat ?? 0) ||
                       existing.coordinate.longitude != (m.lon ?? 0) ||
                       existing.member.drinksCount != m.drinksCount {
                        squadChanged = true
                        break
                    }
                } else {
                    squadChanged = true
                    break
                }
            }
        }
        
        if squadChanged {
            uiView.removeAnnotations(existingSquadAnnotations)
            let newSquadAnnotations = validMembers.map { SquadFriendAnnotation(member: $0) }
            uiView.addAnnotations(newSquadAnnotations)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: CustomMapView
        var lastCenteredId: String? = nil
        var lastCenterTrigger: UUID? = nil
        var lastResetHeadingTrigger: UUID? = nil
        var lastRouteCount: Int = 0
        var wasNavigating: Bool = false
        var wasFollowingUser: Bool = false
        weak var currentUserView: UserHeadingAnnotationView? = nil
        weak var currentManeuverView: CurvedManeuverAnnotationView? = nil
        var currentManeuverStepKey: String? = nil
        var currentManeuverAnnotation: CurvedManeuverAnnotation? = nil
        var lastRouteSignature: String? = nil
        
        init(_ parent: CustomMapView) {
            self.parent = parent
        }
        
        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            // Ce uporabnik rocno premakne zemljevid med navigacijo, zacasno izklopi samodejno sledenje
            if gesture.state == .began && parent.isNavigating && parent.isFollowingUser {
                DispatchQueue.main.async {
                    self.parent.isFollowingUser = false
                }
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            let heading = mapView.camera.heading
            currentManeuverView?.updateRotation(mapHeading: heading)
            if let userView = currentUserView {
                userView.updateHeading(parent.userHeading, mapHeading: heading)
            } else if let userAnnot = mapView.userLocation as MKAnnotation?, let view = mapView.view(for: userAnnot) as? UserHeadingAnnotationView {
                currentUserView = view
                view.updateHeading(parent.userHeading, mapHeading: heading)
            }
            if abs(parent.mapHeading - heading) > 3.0 {
                DispatchQueue.main.async {
                    self.parent.mapHeading = heading
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let polyline = overlay as? MKPolyline {
                return NavigationRoutePolylineRenderer(polyline: polyline)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 1. Uporabniška lokacija: MODRA PIKA z modro smerno puščico
            if annotation is MKUserLocation {
                let identifier = "UserHeadingMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? UserHeadingAnnotationView
                if view == nil {
                    view = UserHeadingAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    view?.annotation = annotation
                }
                view?.updateHeading(parent.userHeading, mapHeading: mapView.camera.heading)
                self.currentUserView = view
                return view
            }
            
            // 2. Dinamična ukrivljena puščica naslednjega zavoja na cestišču
            if let maneuverAnnot = annotation as? CurvedManeuverAnnotation {
                let identifier = "CurvedTurnArrowMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? CurvedManeuverAnnotationView
                if view == nil {
                    view = CurvedManeuverAnnotationView(annotation: maneuverAnnot, reuseIdentifier: identifier)
                } else {
                    view?.annotation = maneuverAnnot
                }
                view?.configure(with: maneuverAnnot, mapHeading: mapView.camera.heading)
                self.currentManeuverView = view
                return view
            }
            
            // 3. Prijatelj iz Pivske Klape (Zlati krog z začetnico in števcem pijač)
            if let squadAnnot = annotation as? SquadFriendAnnotation {
                let identifier = "SquadFriendCustomMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? SquadFriendAnnotationView
                if view == nil {
                    view = SquadFriendAnnotationView(annotation: squadAnnot, reuseIdentifier: identifier)
                } else {
                    view?.annotation = squadAnnot
                }
                view?.configure(with: squadAnnot.member)
                return view
            }
            
            // 4. Označevalec šanka: Čista ZELENA pikica z belim robom
            if let lokalAnnotation = annotation as? LokalAnnotation {
                let identifier = "PubDotMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PubDotAnnotationView
                if view == nil {
                    view = PubDotAnnotationView(annotation: lokalAnnotation, reuseIdentifier: identifier)
                } else {
                    view?.annotation = lokalAnnotation
                }
                view?.setSelectedState(parent.selectedLokal?.id == lokalAnnotation.lokal.id)
                return view
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            mapView.deselectAnnotation(view.annotation, animated: false)
            
            if let annot = view.annotation as? LokalAnnotation {
                for other in mapView.annotations {
                    if let otherLokal = other as? LokalAnnotation,
                       let otherView = mapView.view(for: otherLokal) as? PubDotAnnotationView {
                        let isThis = (otherLokal.lokal.id == annot.lokal.id)
                        otherView.setSelectedState(isThis)
                    }
                }
                parent.onSelectLokal(annot.lokal)
            }
        }
    }
}

// MARK: - Geometrijske pomožne funkcije za smeri in razdalje
private func calculateBearing(from start: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) -> Double {
    let lat1 = start.latitude * .pi / 180.0
    let lon1 = start.longitude * .pi / 180.0
    let lat2 = dest.latitude * .pi / 180.0
    let lon2 = dest.longitude * .pi / 180.0
    
    let dLon = lon2 - lon1
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let radians = atan2(y, x)
    return (radians * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
}

private func distanceBetween(_ c1: CLLocationCoordinate2D, _ c2: CLLocationCoordinate2D) -> Double {
    let loc1 = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
    let loc2 = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
    return loc1.distance(from: loc2)
}

private func calculateRouteWalkingBearing(userLoc: CLLocationCoordinate2D, routeCoords: [CLLocationCoordinate2D]) -> Double? {
    guard routeCoords.count >= 2 else { return nil }
    
    // 1. Poišči točko na trasi, ki je najbližje uporabniku
    var nearestIdx = 0
    var nearestDist = Double.greatestFiniteMagnitude
    for (i, pt) in routeCoords.enumerated() {
        let d = distanceBetween(userLoc, pt)
        if d < nearestDist {
            nearestDist = d
            nearestIdx = i
        }
    }
    
    // 2. Poišči točko naprej vzdolž trase, ki je oddaljena vsaj 12-18 metrov
    // s tem zagotovimo stabilen kot ceste vzdolž ulice brez kakršnegakoli tresenja
    var lookAheadIdx = nearestIdx + 1
    while lookAheadIdx < routeCoords.count {
        let targetPt = routeCoords[lookAheadIdx]
        if distanceBetween(userLoc, targetPt) >= 12.0 {
            break
        }
        lookAheadIdx += 1
    }
    
    if lookAheadIdx >= routeCoords.count {
        lookAheadIdx = routeCoords.count - 1
    }
    
    // 3. Če je uporabnik blizu poti (<30m), vzami natančen vektor ceste med točkami poti
    // (tako se popolnoma odpravi vpliv GPS bočnega odstopanja med pločnikom in cestiščem)
    let aheadPoint = routeCoords[lookAheadIdx]
    let fromPoint: CLLocationCoordinate2D
    if nearestDist < 30.0 {
        if nearestIdx < lookAheadIdx {
            fromPoint = routeCoords[nearestIdx]
        } else if lookAheadIdx > 0 {
            fromPoint = routeCoords[lookAheadIdx - 1]
        } else {
            fromPoint = userLoc
        }
    } else {
        // Če je uporabnik oddaljen od poti, ga usmeri nazaj proti najbližji točki
        return calculateBearing(from: userLoc, to: routeCoords[nearestIdx])
    }
    
    if aheadPoint.latitude != fromPoint.latitude || aheadPoint.longitude != fromPoint.longitude {
        return calculateBearing(from: fromPoint, to: aheadPoint)
    }
    
    return nil
}

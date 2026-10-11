import SwiftUI
import MapKit

// MARK: - OpenStreetMap Mapnik Ploščice s predpomnjenjem
class OSMTileOverlay: MKTileOverlay {
    private let tileCache = NSCache<NSString, NSData>()
    
    init() {
        super.init(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        // canReplaceMapContent = false omogoča zvezno Apple Maps podlago,
        // tako da uporabnik NIKOLI ne izgubi karte ob hitrem zumiranju ali pomanjkanju povezave!
        self.canReplaceMapContent = false
        self.tileSize = CGSize(width: 256, height: 256)
        self.maximumZ = 19
        self.minimumZ = 1
        tileCache.countLimit = 800
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
        
        let tileUrl = self.url(forTilePath: path)
        var request = URLRequest(url: tileUrl)
        request.setValue("SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let data = data {
                self?.tileCache.setObject(data as NSData, forKey: key)
                result(data, nil)
            } else {
                result(nil, error)
            }
        }.resume()
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
        
        // Glavni zeleni krog (#2E7D32)
        dotView.frame = CGRect(x: 1, y: 1, width: 24, height: 24)
        dotView.backgroundColor = UIColor(red: 46/255, green: 125/255, blue: 50/255, alpha: 1.0)
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
                self.dotView.backgroundColor = UIColor(red: 67/255, green: 160/255, blue: 71/255, alpha: 1.0)
                self.innerDot.backgroundColor = UIColor(red: 255/255, green: 213/255, blue: 79/255, alpha: 1.0)
            } else {
                self.transform = .identity
                self.dotView.backgroundColor = UIColor(red: 46/255, green: 125/255, blue: 50/255, alpha: 1.0)
                self.innerDot.backgroundColor = UIColor.white
            }
        }
    }
}

// MARK: - Označevalec prijatelja iz Pivske Klape
class SquadFriendAnnotation: NSObject, MKAnnotation {
    let member: SquadMember
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: member.lat ?? 46.0569, longitude: member.lon ?? 14.5058)
    }
    // Zasebnost: prikazuje le ime brez štetja pijač
    var title: String? { member.name }
    var subtitle: String? { "Pivska Klapa" }
    
    init(member: SquadMember) {
        self.member = member
        super.init()
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
    
    func updateHeading(_ heading: Double) {
        let radians = CGFloat(heading * .pi / 180.0)
        UIView.animate(withDuration: 0.12) {
            self.containerView.transform = CGAffineTransform(rotationAngle: radians)
        }
    }
}

// MARK: - Označevalec za puščico naslednjega zavoja na poti
class RouteManeuverAnnotation: NSObject, MKAnnotation {
    let stepIndex: Int
    let coordinate: CLLocationCoordinate2D
    let modifier: String?
    let title: String?
    let subtitle: String?
    
    init(stepIndex: Int, coordinate: CLLocationCoordinate2D, modifier: String?, instruction: String) {
        self.stepIndex = stepIndex
        self.coordinate = coordinate
        self.modifier = modifier
        self.title = instruction
        self.subtitle = modifier
        super.init()
    }
}

// MARK: - Pogled za puščico zavoja na trasi (Zeleni krog z belo puščico in senco)
class RouteManeuverAnnotationView: MKAnnotationView {
    private let badgeView = UIView()
    private let iconImageView = UIImageView()
    
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
        self.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        self.centerOffset = CGPoint(x: 0, y: 0)
        
        badgeView.frame = CGRect(x: 2, y: 2, width: 32, height: 32)
        badgeView.backgroundColor = UIColor(red: 27/255, green: 94/255, blue: 32/255, alpha: 1.0) // Temno zelena #1B5E20
        badgeView.layer.cornerRadius = 16
        badgeView.layer.borderWidth = 2.5
        badgeView.layer.borderColor = UIColor.white.cgColor
        badgeView.layer.shadowColor = UIColor.black.cgColor
        badgeView.layer.shadowOpacity = 0.45
        badgeView.layer.shadowOffset = CGSize(width: 0, height: 2)
        badgeView.layer.shadowRadius = 3
        addSubview(badgeView)
        
        iconImageView.frame = CGRect(x: 6, y: 6, width: 20, height: 20)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        badgeView.addSubview(iconImageView)
        
        updateIcon()
    }
    
    func updateIcon() {
        guard let annot = annotation as? RouteManeuverAnnotation else { return }
        let mod = annot.modifier?.lowercased() ?? ""
        let iconName: String
        if mod.contains("left") {
            if mod.contains("sharp") {
                iconName = "arrow.uturn.backward"
            } else if mod.contains("slight") {
                iconName = "arrow.up.left"
            } else {
                iconName = "arrow.turn.up.left"
            }
        } else if mod.contains("right") {
            if mod.contains("sharp") {
                iconName = "arrow.uturn.forward"
            } else if mod.contains("slight") {
                iconName = "arrow.up.right"
            } else {
                iconName = "arrow.turn.up.right"
            }
        } else if mod.contains("u-turn") || mod.contains("uturn") {
            iconName = "arrow.uturn.down"
        } else {
            iconName = "arrow.up"
        }
        
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        iconImageView.image = UIImage(systemName: iconName, withConfiguration: config)
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
    var userHeading: Double = 0.0
    var bars: [Lokal]
    var squadMembers: [SquadMember] = []
    var selectedLokal: Lokal?
    var routeCoordinates: [CLLocationCoordinate2D]
    var routeSteps: [OsrmStep] = []
    var onSelectLokal: (Lokal) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Prepreči prikaz nezaželenih Apple ikon in stavb
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        
        // OpenStreetMap ploščice dodamo na .aboveRoads, tako da je Apple Maps podlaga vedno aktivna,
        // navigacijska trasa pa bo dodana na .aboveLabels in se NIKOLI ne izgubi ali prekrije!
        let osmOverlay = OSMTileOverlay()
        mapView.addOverlay(osmOverlay, level: .aboveRoads)
        
        let startCoord = centerCoordinate ?? LocationManager.defaultCoordinate
        let region = MKCoordinateRegion(center: startCoord, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015))
        mapView.setRegion(region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.currentUserView?.updateHeading(userHeading)
        
        if let center = centerCoordinate, context.coordinator.lastCenteredId != "\(center.latitude),\(center.longitude)" {
            context.coordinator.lastCenteredId = "\(center.latitude),\(center.longitude)"
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
            uiView.setRegion(region, animated: true)
        }
        
        // 1. Posodobitev navigacijske rute
        let currentPolylines = uiView.overlays.compactMap { $0 as? MKPolyline }
        uiView.removeOverlays(currentPolylines)
        
        if !routeCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            // Ključno: Polyline dodamo na .aboveLabels, s čimer je 100% zagotovljeno,
            // da je črta vedno na vrhu nad ploščicami pri vseh stopnjah zumiranja!
            uiView.addOverlay(polyline, level: .aboveLabels)
            
            // Samodejno prilagodi pogled na celotno traso, ko se nova pot naloži
            if context.coordinator.lastRouteCount != routeCoordinates.count {
                context.coordinator.lastRouteCount = routeCoordinates.count
                let edgeInsets = UIEdgeInsets(top: 100, left: 60, bottom: 200, right: 60)
                uiView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: edgeInsets, animated: true)
            }
            
            // Odznači označevalce, da ne motijo navigacije
            uiView.selectedAnnotations = []
        } else {
            context.coordinator.lastRouteCount = 0
        }
        
        // 2. Posodobitev puščic za zavoje na cesti (Route Maneuver Turn Arrows)
        let existingManeuvers = uiView.annotations.compactMap { $0 as? RouteManeuverAnnotation }
        uiView.removeAnnotations(existingManeuvers)
        
        if !routeCoordinates.isEmpty && !routeSteps.isEmpty {
            var maneuverAnnotations: [RouteManeuverAnnotation] = []
            for (idx, step) in routeSteps.enumerated() {
                guard let maneuver = step.maneuver,
                      let loc = maneuver.location, loc.count >= 2 else { continue }
                let coord = CLLocationCoordinate2D(latitude: loc[1], longitude: loc[0])
                
                // Ustvari puščico za zavoje na križiščih
                let mod = maneuver.modifier?.lowercased()
                if mod != nil && mod != "straight" {
                    let annot = RouteManeuverAnnotation(
                        stepIndex: idx,
                        coordinate: coord,
                        modifier: maneuver.modifier,
                        instruction: maneuver.instructionText
                    )
                    maneuverAnnotations.append(annot)
                }
            }
            uiView.addAnnotations(maneuverAnnotations)
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
        
        // 4. Posodobitev prijateljev iz Pivske Klape
        let existingSquadAnnotations = uiView.annotations.compactMap { $0 as? SquadFriendAnnotation }
        let existingSquadIds = Set(existingSquadAnnotations.map { $0.member.id })
        let newSquadIds = Set(squadMembers.filter { $0.lat != nil && $0.lon != nil }.map { $0.id })
        
        if existingSquadIds != newSquadIds {
            uiView.removeAnnotations(existingSquadAnnotations)
            let newSquadAnnotations = squadMembers
                .filter { $0.lat != nil && $0.lon != nil }
                .map { SquadFriendAnnotation(member: $0) }
            uiView.addAnnotations(newSquadAnnotations)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CustomMapView
        var lastCenteredId: String? = nil
        var lastRouteCount: Int = 0
        weak var currentUserView: UserHeadingAnnotationView? = nil
        
        init(_ parent: CustomMapView) {
            self.parent = parent
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
                view?.updateHeading(parent.userHeading)
                self.currentUserView = view
                return view
            }
            
            // 2. Puščice zavojev na trasi (Maneuver Turn Arrows)
            if let maneuverAnnot = annotation as? RouteManeuverAnnotation {
                let identifier = "ManeuverArrowMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? RouteManeuverAnnotationView
                if view == nil {
                    view = RouteManeuverAnnotationView(annotation: maneuverAnnot, reuseIdentifier: identifier)
                } else {
                    view?.annotation = maneuverAnnot
                    view?.updateIcon()
                }
                return view
            }
            
            // 3. Prijatelj iz Pivske Klape (zlati krog)
            if let squadAnnot = annotation as? SquadFriendAnnotation {
                let identifier = "SquadFriendMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: squadAnnot, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                    view?.clusteringIdentifier = nil
                } else {
                    view?.annotation = squadAnnot
                }
                view?.markerTintColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
                view?.glyphText = String(squadAnnot.member.name.prefix(1)).uppercased()
                view?.glyphTintColor = UIColor.black
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
                (view as? PubDotAnnotationView)?.setSelectedState(true)
                parent.onSelectLokal(annot.lokal)
            }
        }
    }
}

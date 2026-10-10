import SwiftUI
import MapKit

// MARK: - OpenStreetMap Mapnik Ploščice (Zanesljivo & brez "API Key Required" vodnega žiga!)
class OSMTileOverlay: MKTileOverlay {
    init() {
        super.init(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        self.canReplaceMapContent = false // Če ploščice še niso naložene, se vidi podlaga namesto praznine
        self.tileSize = CGSize(width: 256, height: 256)
        self.maximumZ = 19
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        return URL(string: "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
    }
    
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let tileUrl = self.url(forTilePath: path)
        var request = URLRequest(url: tileUrl)
        request.setValue("SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            result(data, error)
        }.resume()
    }
}

// MARK: - Označevalec lokala
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

// MARK: - Označevalec prijatelja iz Pivske Klape
class SquadFriendAnnotation: NSObject, MKAnnotation {
    let member: SquadMember
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: member.lat ?? 46.0569, longitude: member.lon ?? 14.5058)
    }
    var title: String? { "\(member.name) (🍻 \(member.drinksCount))" }
    var subtitle: String? { "Pivska Klapa" }
    
    init(member: SquadMember) {
        self.member = member
        super.init()
    }
}

// MARK: - Pogled lokacije uporabnika s smerno puščico kompasa (Google Maps / Android slog)
class UserHeadingAnnotationView: MKAnnotationView {
    private let containerView = UIView()
    private let arrowLayer = CAShapeLayer()
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
        self.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        self.centerOffset = CGPoint(x: 0, y: 0)
        self.canShowCallout = false
        
        containerView.frame = self.bounds
        addSubview(containerView)
        
        // 1. Smerni trikotnik / puščica (modra #1A73E8)
        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: 22, y: 2))
        arrowPath.addLine(to: CGPoint(x: 16, y: 14))
        arrowPath.addLine(to: CGPoint(x: 28, y: 14))
        arrowPath.close()
        
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.fillColor = UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0).cgColor
        containerView.layer.addSublayer(arrowLayer)
        
        // 2. Glavni moder krog z belo obrobo
        dotView.frame = CGRect(x: 11, y: 11, width: 22, height: 22)
        dotView.backgroundColor = UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0)
        dotView.layer.cornerRadius = 11
        dotView.layer.borderWidth = 3.0
        dotView.layer.borderColor = UIColor.white.cgColor
        dotView.layer.shadowColor = UIColor.black.cgColor
        dotView.layer.shadowOpacity = 0.35
        dotView.layer.shadowOffset = CGSize(width: 0, height: 2)
        dotView.layer.shadowRadius = 4
        containerView.addSubview(dotView)
        
        // 3. Notranja bela pika za natančnost
        innerDot.frame = CGRect(x: 19, y: 19, width: 6, height: 6)
        innerDot.backgroundColor = UIColor.white
        innerDot.layer.cornerRadius = 3
        containerView.addSubview(innerDot)
    }
    
    func updateHeading(_ heading: Double) {
        let radians = CGFloat(heading * .pi / 180.0)
        UIView.animate(withDuration: 0.15) {
            self.containerView.transform = CGAffineTransform(rotationAngle: radians)
        }
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
    var onSelectLokal: (Lokal) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // OpenStreetMap Mapnik uradne ploščice (brez vodnega žiga!)
        let osmOverlay = OSMTileOverlay()
        mapView.addOverlay(osmOverlay, level: .aboveRoads)
        
        // Začetni pogled (center Ljubljane ali trenutna lokacija)
        let startCoord = centerCoordinate ?? LocationManager.defaultCoordinate
        let region = MKCoordinateRegion(center: startCoord, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015))
        mapView.setRegion(region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Posodobi smer kompasa uporabniške puščice
        context.coordinator.currentUserView?.updateHeading(userHeading)
        
        // Če se spremeni centerCoordinate in ni še centrirano
        if let center = centerCoordinate, context.coordinator.lastCenteredId != "\(center.latitude),\(center.longitude)" {
            context.coordinator.lastCenteredId = "\(center.latitude),\(center.longitude)"
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
            uiView.setRegion(region, animated: true)
        }
        
        // Posodobi navigacijsko pot (Polyline)
        let currentPolylines = uiView.overlays.compactMap { $0 as? MKPolyline }
        uiView.removeOverlays(currentPolylines)
        
        if !routeCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            uiView.addOverlay(polyline, level: .aboveRoads)
            
            // Samodejno približaj na traso
            let rect = polyline.boundingMapRect
            uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 100, left: 40, bottom: 220, right: 40), animated: true)
        }
        
        // Posodobi označevalce lokalov (Pins)
        let existingLokalAnnotations = uiView.annotations.compactMap { $0 as? LokalAnnotation }
        let existingBarIds = Set(existingLokalAnnotations.map { $0.lokal.id })
        let newBarIds = Set(bars.map { $0.id })
        
        if existingBarIds != newBarIds {
            uiView.removeAnnotations(existingLokalAnnotations)
            let newAnnotations = bars.map { LokalAnnotation(lokal: $0) }
            uiView.addAnnotations(newAnnotations)
        }
        
        // Posodobi označevalce Pivske Klape
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
        
        // Posodobi izbranega
        if let selected = selectedLokal {
            if let annot = uiView.annotations.compactMap({ $0 as? LokalAnnotation }).first(where: { $0.lokal.id == selected.id }) {
                uiView.selectAnnotation(annot, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CustomMapView
        var lastCenteredId: String? = nil
        weak var currentUserView: UserHeadingAnnotationView? = nil
        
        init(_ parent: CustomMapView) {
            self.parent = parent
        }
        
        // Risanje OSM ploščic in OSRM modre navigacijske rute
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0) // Google Maps modra #1A73E8
                renderer.lineWidth = 7.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // Označevalci na zemljevidu (uporabnik s puščico, šanki in prijatelji iz klape)
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 1. Uporabniška pikica s smerno puščico
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
            
            // 2. Označevalec prijatelja iz Pivske Klape
            if let squadAnnot = annotation as? SquadFriendAnnotation {
                let identifier = "SquadFriendMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: squadAnnot, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = squadAnnot
                }
                view?.markerTintColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0) // Zlata #F59E0B
                view?.glyphText = String(squadAnnot.member.name.prefix(1)).uppercased()
                view?.glyphTintColor = UIColor.black
                return view
            }
            
            // 3. Označevalci piva na zemljevidu (zeleni z pivom)
            if let lokalAnnotation = annotation as? LokalAnnotation {
                let identifier = "SankMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: lokalAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                    view?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                } else {
                    view?.annotation = lokalAnnotation
                }
                
                view?.markerTintColor = UIColor(red: 46/255, green: 125/255, blue: 50/255, alpha: 1.0) // Zelena kot na Androidu
                view?.glyphText = "🍺"
                return view
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annot = view.annotation as? LokalAnnotation else { return }
            parent.onSelectLokal(annot.lokal)
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let annot = view.annotation as? LokalAnnotation else { return }
            parent.onSelectLokal(annot.lokal)
        }
    }
}

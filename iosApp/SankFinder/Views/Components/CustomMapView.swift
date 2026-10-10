import SwiftUI
import MapKit

class OpenStreetTileOverlay: MKTileOverlay {
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // Carto Voyager (enak kot v Android verziji ŠankFinderja)
        // Podpira tudi standardni OpenStreetMap: https://tile.openstreetmap.org/{z}/{x}/{y}.png
        let urlString = "https://basemaps.cartocdn.com/rastertiles/voyager/\(path.z)/\(path.x)/\(path.y).png"
        return URL(string: urlString) ?? super.url(forTilePath: path)
    }
}

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

struct CustomMapView: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D?
    var bars: [Lokal]
    var selectedLokal: Lokal?
    var routeCoordinates: [CLLocationCoordinate2D]
    var onSelectLokal: (Lokal) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // 1. Zamenjaj Applov privzeti zemljevid s tvojim OpenStreetMap / Carto Voyager
        let tileOverlay = OpenStreetTileOverlay()
        tileOverlay.canReplaceMapContent = true // Popolnoma prekrije Apple Maps!
        mapView.addOverlay(tileOverlay, level: .aboveLabels)
        
        // Začetni pogled
        let startCoord = centerCoordinate ?? LocationManager.defaultCoordinate
        let region = MKCoordinateRegion(center: startCoord, latitudinalMeters: 1200, longitudinalMeters: 1200)
        mapView.setRegion(region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Posodobi pot (Polyline)
        let currentPolylines = uiView.overlays.compactMap { $0 as? MKPolyline }
        uiView.removeOverlays(currentPolylines)
        
        if !routeCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            uiView.addOverlay(polyline, level: .aboveRoads)
        }
        
        // Posodobi označevalce lokalov (Pins)
        let existingAnnotations = uiView.annotations.compactMap { $0 as? LokalAnnotation }
        let existingIds = Set(existingAnnotations.map { $0.lokal.id })
        let newIds = Set(bars.map { $0.id })
        
        if existingIds != newIds {
            uiView.removeAnnotations(existingAnnotations)
            let newAnnotations = bars.map { LokalAnnotation(lokal: $0) }
            uiView.addAnnotations(newAnnotations)
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
        
        init(_ parent: CustomMapView) {
            self.parent = parent
        }
        
        // Risanje ploščic in rute
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Theme.beerGold)
                renderer.lineWidth = 6.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // Označevalci piva na zemljevidu
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let lokalAnnotation = annotation as? LokalAnnotation else { return nil }
            
            let identifier = "LokalMarker"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: lokalAnnotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = lokalAnnotation
            }
            
            view?.markerTintColor = UIColor(Theme.beerGold)
            view?.glyphText = "🍺"
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annot = view.annotation as? LokalAnnotation else { return }
            parent.onSelectLokal(annot.lokal)
        }
    }
}

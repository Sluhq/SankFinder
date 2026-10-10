import SwiftUI
import MapKit

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
        
        // Carto Voyager ploščice (OpenStreetMap)
        let tileOverlay = MKTileOverlay(urlTemplate: "https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png")
        tileOverlay.tileSize = CGSize(width: 256, height: 256)
        tileOverlay.canReplaceMapContent = false // Zanesljivo: če ploščice še nalagajo, ni praznega ekrana
        mapView.addOverlay(tileOverlay, level: .aboveRoads)
        
        // Začetni pogled (center Ljubljane ali trenutna lokacija)
        let startCoord = centerCoordinate ?? LocationManager.defaultCoordinate
        let region = MKCoordinateRegion(center: startCoord, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015))
        mapView.setRegion(region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Če se spremeni centerCoordinate in ni še centrirano
        if let center = centerCoordinate, context.coordinator.lastCenteredId != "\(center.latitude),\(center.longitude)" {
            context.coordinator.lastCenteredId = "\(center.latitude),\(center.longitude)"
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
            uiView.setRegion(region, animated: true)
        }
        
        // Posodobi pot (Polyline)
        let currentPolylines = uiView.overlays.compactMap { $0 as? MKPolyline }
        uiView.removeOverlays(currentPolylines)
        
        if !routeCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            uiView.addOverlay(polyline, level: .aboveRoads)
            
            // Samodejno približaj na traso
            let rect = polyline.boundingMapRect
            uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 200, right: 40), animated: true)
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
        var lastCenteredId: String? = nil
        
        init(_ parent: CustomMapView) {
            self.parent = parent
        }
        
        // Risanje ploščic in OSRM rute
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
        
        // Označevalci piva na zemljevidu (identični kot na Androidu: zeleni z belim obročem in pivom)
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let lokalAnnotation = annotation as? LokalAnnotation else { return nil }
            
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

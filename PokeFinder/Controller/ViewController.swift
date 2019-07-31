//
//  ViewController.swift
//  PokeFinder
//
//  Created by Teodora Knezevic on 7/16/19.
//  Copyright © 2019 Teodora Knezevic. All rights reserved.
//

import UIKit
import MapKit
import FirebaseDatabase
import GeoFire

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    
    @IBOutlet weak var mapView: MKMapView!
    let locationManager = CLLocationManager()
    var mapHasCenteredOnce = false
    
    var geoFire:GeoFire!
    var geoFireRef:DatabaseReference!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        mapView.userTrackingMode = MKUserTrackingMode.follow   // prati korisnikovu lokaciju
        
        geoFireRef = Database.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireRef)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        locationAuthStatus()
    }

    func locationAuthStatus(){
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        }else{
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        }
    }
    
    func centerMapOnLocation(location:CLLocation){
        
        let coordinateRegion = MKCoordinateRegion.init(center: location.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    //govori delegatu da je korisnikova lokacija update-ovana
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {  // centrira mapu samo 1 na pocetku
       
        if let loc = userLocation.location {

            if !mapHasCenteredOnce {
                centerMapOnLocation(location: loc)
                mapHasCenteredOnce = true
            }
        }
    }
    
    
    // kaze delegatu da ce region da se promeni. Hocemo da kad korisnik pomeri mapu da se prikazu i pokemoni u tom novom delu mape
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        showSightingsOnMap(location: loc)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        var annotView:MKAnnotationView?
        
        if annotation.isKind(of: MKUserLocation.self){
            
            annotView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            annotView?.image = UIImage(named: "ash")
            
        } else if let deqAnno = mapView.dequeueReusableAnnotationView(withIdentifier: "Pokemon"){
            
            annotView = deqAnno
            annotView?.annotation = annotation
            
        } else {
            
            let av = MKAnnotationView(annotation: annotation, reuseIdentifier: "Pokemon")
            av.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotView = av
        }
        
        if let annotationView = annotView, let anno = annotation as? PokeAnnotation {
            
            annotationView.canShowCallout = true  // True oznacava da je annotationView u mogucnosti da prikaze dodatnu informaciju u 'oblacicu'
            annotationView.image = UIImage(named: "\(anno.pokemonNumber)")
            
            let btn = UIButton()
            btn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            btn.setImage(UIImage(named: "map"), for: .normal)
            
            annotationView.rightCalloutAccessoryView = btn
        }
        
        return annotView
    }
    
    
    //kaze delegatu da je korisnik pritisnuo dodatno dugme anotacije - u nasem slucaju onu slicicu mape
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        if let anno = view.annotation as? PokeAnnotation {
            
            // sad konfigurisemo APPLE MAPU
            let place = MKPlacemark(coordinate: anno.coordinate)
            let destination = MKMapItem(placemark: place)
            destination.name = "Pokemon sighting" // ovo ce biti u Apple mapi kad se otvori
            
            let regionDistance:CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegion(center: anno.coordinate, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
            
            let options = [MKLaunchOptionsMapCenterKey:NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey:NSValue(mkCoordinateSpan: regionSpan.span), MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
    }
    
    
    func createSighting(forLocation location:CLLocation, withPokemonId pokeId:Int){
        geoFire.setLocation(location, forKey:"\(pokeId)")      // update-je lokaciju za odredjeni kljuc
                                                              // Ubaci u Firebase bazu za tu lokaciju-pokemona sa tim id-jem
    }
    
    // Kad god dobijemo korisnikovu lokaciju - prikazi sve pokemone na mapi ( kreiracemo upit )
    func showSightingsOnMap(location:CLLocation){
        
        let circleQuery = geoFire!.query(at: location, withRadius: 2.5)
        
        _ = circleQuery.observe(.keyEntered, with: {(key:String!, location:CLLocation!) in   //U ovom radijusu slusaj ako se doda neki kljuc
                                                                                            //Ako imamo 50 pokemona ovaj blok se poziva 50x
            
            if let key = key, let loc = location {
                
                let annot = PokeAnnotation(coordinate: loc.coordinate, pokemonNumber: Int(key)!)
                self.mapView.addAnnotation(annot)
            }
        })
    }
    
    
    //Kad se pritisne dugme - stavi proizvoljnog Pokemona tacno na CENTAR mape
    @IBAction func spotRandomPokemon(_ sender: Any) {
        
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        let rand = arc4random_uniform(151) + 1 // nasumicno; gornja granica=151 Donja=1, jer niz pokemon ide od 0 do 150
        
        createSighting(forLocation: loc, withPokemonId: Int(rand))
    }
    
}


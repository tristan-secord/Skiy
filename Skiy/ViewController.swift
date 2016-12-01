//
//  ViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-04-09.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit
import MapKit

protocol ViewControllerDelegate {
}

class marker {
    var name: String? = nil
    var pinView: MKPointAnnotation? = nil
    
    init(name: String, pinView: MKPointAnnotation) {
        self.name = name
        self.pinView = pinView
    }
    
    func changeLocation (loc_coords: CLLocationCoordinate2D) {
        if pinView != nil {
            pinView!.coordinate = loc_coords
        }
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    var delegate: ViewControllerDelegate?
    let regionRadius: CLLocationDistance = 1000
    var markerArray: Array<marker> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewWidth = self.view.frame.width
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        //Making Blurred Navigation Bar
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(x: 0, y: 0, width: viewWidth, height: 66)
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    func locationUpdate(_ latitude: Double, longitude: Double, friend: String) {
        let loc_coords : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: latitude , longitude: longitude)
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(loc_coords, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)

        //Check if already have a pin for this user
        if let markerIndex = markerArray.index(where: { $0.name == friend }) {
            //Change location
            let marker = markerArray[markerIndex]
            marker.changeLocation(loc_coords: loc_coords)
        } else {
            //Create new pin and add to marker array
            let dropPin = MKPointAnnotation()
            dropPin.coordinate = loc_coords
            dropPin.title = friend
            mapView.addAnnotation(dropPin)
            let newMarker: marker = marker(name: friend, pinView: dropPin)
            markerArray.append(newMarker)
        }
    }
    
    func setLocation(_ location: CLLocation) {
        let loc_coords: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(loc_coords, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // If it's the user location, just return nil.
        if annotation.isKind(of: MKUserLocation.self) { return nil }
        
        if annotation.isKind(of: MKPointAnnotation.self) {
            var pinView: MKAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: "CustomPinAnnotationView") {
                dequeuedView.annotation = annotation
                pinView = dequeuedView
            } else {
                pinView = MKAnnotationView(annotation: annotation, reuseIdentifier: "CustomPinAnnotationView")
                pinView.canShowCallout = true;
                pinView.image = UIImage(named: "friendLocation")
                pinView.frame.size = CGSize(width: 50, height: 50)
            }
            return pinView
        }
        return nil
    }
}

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

class ViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    var delegate: ViewControllerDelegate?
    
    let regionRadius: CLLocationDistance = 1000
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewWidth = self.view.frame.width
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        //Making Blurred Navigation Bar
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRectMake(0, 0, viewWidth, 66)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }

    func locationUpdate(latitude: Double, longitude: Double, friend: String) {
        let loc_coords : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: latitude , longitude: longitude)
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(loc_coords, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)

        // Drop a pin
        let dropPin = MKPointAnnotation()
        dropPin.coordinate = loc_coords
        dropPin.title = friend
        mapView.addAnnotation(dropPin)
    }
    
    func setLocation(location: CLLocation) {
        let loc_coords: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(loc_coords, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        // If it's the user location, just return nil.
        if annotation.isKindOfClass(MKUserLocation) { return nil }
        
        if annotation.isKindOfClass(MKPointAnnotation) {
            //var pinView: MKAnnotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("CustomPinAnnotationView")!
            //if (pinView) {
            var pinView: MKAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier("CustomPinAnnotationView") {
                dequeuedView.annotation = annotation
                pinView = dequeuedView
            } else {
                pinView = MKAnnotationView(annotation: annotation, reuseIdentifier: "CustomPinAnnotationView")
                pinView.canShowCallout = true;
                pinView.image = UIImage(named: "Location Icon Color")
            }
            return pinView
        }
        return nil
    }
}

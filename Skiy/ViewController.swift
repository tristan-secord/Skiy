//
//  ViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-04-09.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var navbarTitle: UINavigationBar!
    
    let initialLocation = CLLocation(latitude: 21.282778, longitude: -157.829444)
    let regionRadius: CLLocationDistance = 1000
    var friends: [String : CLLocation] = ["Pyke S." : CLLocation(latitude: 21.282778, longitude: -157.829444), "Sandra Secord" : CLLocation(latitude: 43.653226, longitude: -79.383184), "Mike Secord" : CLLocation(latitude: 43.921302, longitude: -79.531294)]
    var index: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centerMapOnLocation(initialLocation)
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.handleSwipes(_:)))
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.handleSwipes(_:)))
        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.handleSwipes(_:)))
        
        leftSwipe.direction = .Left
        rightSwipe.direction = .Right
        downSwipe.direction = .Down
        
        navbarTitle.addGestureRecognizer(leftSwipe)
        navbarTitle.addGestureRecognizer(rightSwipe)
        navbarTitle.addGestureRecognizer(downSwipe)
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                  regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func handleSwipes(sender:UISwipeGestureRecognizer) {
        if (sender.direction == .Left) {
            if (index != friends.count - 1) {
                index += 1
                let dicIndex = friends.startIndex.advancedBy(index)
                let friendName = friends.keys[dicIndex]
                navbarTitle.topItem!.title = friendName
                centerMapOnLocation(friends[friendName]!)
            }
        }
        
        if (sender.direction == .Right) {
            if (index != 0) {
                index -= 1
                let dicIndex = friends.startIndex.advancedBy(index)
                let friendName = friends.keys[dicIndex]
                navbarTitle.topItem!.title = friendName
                centerMapOnLocation(friends[friendName]!)
                
            }
        }
        
        if (sender.direction == .Down) {
            print("Swipe Down")
        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
}


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
    
    var delegate: ViewControllerDelegate?
    
    let initialLocation = CLLocation(latitude: 21.282778, longitude: -157.829444)
    let regionRadius: CLLocationDistance = 1000
    var friends: [String : CLLocation] = ["Pyke S." : CLLocation(latitude: 21.282778, longitude: -157.829444), "Sandra Secord" : CLLocation(latitude: 43.653226, longitude: -79.383184), "Mike Secord" : CLLocation(latitude: 43.921302, longitude: -79.531294)]
    var index: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewWidth = self.view.frame.width
        
        //Making Blurred Navigation Bar (PYKE S.)
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRectMake(0, 0, viewWidth, 66)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
}

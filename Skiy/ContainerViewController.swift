//
//  ContainerViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-05-21.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit
import ActionCableClient
import CoreData
import MapKit

enum errorTitles: String {
    case woops = "Woops!"
    case uhoh = "Uh Oh..."
    case notquite = "Not Quite!"
}

class ContainerViewController: UIViewController {
    
    enum controllerState {
        case Hidden
        case Visible
    }
    
    var currentState = controllerState.Hidden
    var controlPanelViewController: ControlPanelViewController!
    var mapViewController: ViewController!
    var signInViewController: SignInViewController!
    var addFriendViewController: AddFriendViewController?
    var notificationsViewController: NotificationsViewController?
    var viewWidth: CGFloat = 0.0
    var viewHeight: CGFloat = 0.0
    var blurView = UIImageView()
    let defaults = NSUserDefaults.standardUserDefaults()
    let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
    let statusBarHeight =
        UIApplication.sharedApplication().statusBarFrame.size.height
    let httpHelper = HTTPHelper()
    let client = ActionCableClient(URL: NSURL(string: "ws://immense-forest-45065.herokuapp.com/cable")!)
    let locationManager = CLLocationManager()
    
    //NEED TO UPDATE THESE INTERNAL ARRAYS!
    var activeSessions = Array<NSManagedObject>()
    var requestedSessions = Array<NSManagedObject>()
    var pendingSessions = Array<NSManagedObject>()
    var cancelledSessions = Array<NSManagedObject>()
    var currentSession: NSManagedObject? = nil
    
    var sendChannel: Channel? = nil
    var requestChannel: Channel? = nil
    
    var isInitialized: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            print("Location Services Enabled")
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
            locationManager.allowsBackgroundLocationUpdates = true
        }
    
        viewWidth = view.frame.size.width
        viewHeight = view.frame.size.height
        
        //instantiate mapViewController
        mapViewController = UIStoryboard.mapViewController()
        mapViewController.view.frame = CGRectMake(0, 0, viewWidth, viewHeight)
        mapViewController.delegate = self
        view.addSubview(mapViewController.view)
        addChildViewController(mapViewController)
        mapViewController.didMoveToParentViewController(self)
        
        //instantiate controlPanelViewController
        instantiateControlPanelViewController()
        
        //instantiate signInViewController
        signInViewController = UIStoryboard.signInViewController()
        signInViewController.delegate = self
        signInViewController.view.frame = CGRectMake(0, 0, viewWidth, viewHeight)
    }
    
    func instantiateControlPanelViewController() {
        controlPanelViewController = UIStoryboard.controlPanelViewController()
        controlPanelViewController.delegate = self
        controlPanelViewController.view.frame = CGRectMake(0, -viewHeight, viewWidth, viewHeight + 66 + statusBarHeight)
        
        //add Gesture Recognizer to control panel
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ContainerViewController.handlePanGesture(_:)))
        controlPanelViewController!.view.addGestureRecognizer(panGestureRecognizer)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        
        //try and use single map
        if defaults.objectForKey("userLoggedIn") == nil {
            controlPanelViewController.clearCoreData("Friend")
            controlPanelViewController.clearCoreData("Notification")
            controlPanelViewController.clearCoreData("Session")
            hideContentController(controlPanelViewController, animation: true)
            displayContentController(signInViewController, animation: true)
        } else {
            displayContentController(controlPanelViewController, animation: true)
            hideContentController(signInViewController, animation: true)
        }
    }
    
    func hideContentController(content: UIViewController, animation: Bool) {
        content.willMoveToParentViewController(nil)
        if (animation == true) {
            UIView.animateWithDuration(0.5, animations: {content.view.alpha = 0.0},
                                       completion: {(value: Bool) in
                                        content.view.removeFromSuperview()
            })
        } else {
            content.view.removeFromSuperview()
        }
        content.removeFromParentViewController()
    }
    
    func displayContentController(content: UIViewController, animation: Bool) {
        addChildViewController(content)
        content.view.alpha = 0.0
        UIView.animateWithDuration(0.5, animations: {content.view.alpha = 1.0},
                                    completion: {(value: Bool) in
                                    self.view.addSubview(content.view)
        })
        content.didMoveToParentViewController(self)
    }
    
    func locationRequested(data: [String: AnyObject]) {
        if let sessionId = data["id"] as? Int {
            //save to CoreData
            saveSessionToCoreData(data)
            //connect to websocket
            connectToRequestingWebSocket(sessionId)
            
            if controlPanelViewController != nil {
                controlPanelViewController.updateMap(data)
                if !updateCurrentSession(sessionId) {
                    print("Could not update current session")
                }
            }
            
            self.showSession(data)
        }
    }
    
    func showSession(data: [String:AnyObject]) {
        if let sessionId = data["id"] as? Int {
            //updateCurrentSession
            self.updateCurrentSession(sessionId)
            
            //Show Map
            if controlPanelViewController != nil {
                print("Updating Map")
                controlPanelViewController.updateMap(data)
            }
            animateControlPanel(false)
        }
    }
    
    func updateCurrentSession(session_id: Int) -> Bool {
        if let userIndex = requestedSessions.indexOf({ $0.valueForKey("id") as! Int == session_id }) {
            currentSession = requestedSessions[userIndex]
        } else if let userIndex = activeSessions.indexOf({ $0.valueForKey("id") as! Int == session_id }) {
            currentSession = activeSessions[userIndex]
        } else {
            return false
        }
        
        return true
    }
    
    func saveSessionToCoreData(data: [String: AnyObject]) {
        //create an expiry date of 3 hours -> 3 * 60 * 60 (seconds)
        let expiry_date = NSDate()
        expiry_date.dateByAddingTimeInterval(3 * 60 * 60) // GET EXPIRY DATE FROM SERVER!!!
        //save session to core data
        if let channel = data["channel_name"] as? String,
            user_id = data["user_id"] as? Int,
            friend_id = data["friend_id"] as? Int,
            status = data["status"] as? String,
            type = data["request_type"] as? String,
            id = data["id"] as? Int{
            
            let appDelegate =
                UIApplication.sharedApplication().delegate as! AppDelegate
            
            let managedContext = appDelegate.managedObjectContext
            
            // Initialize Fetch Request
            let fetchRequest = NSFetchRequest()
            
            //Configure predicate
            let predicate : NSPredicate = NSPredicate(format: "id == %@", NSNumber(integer: id))
            
            // Create Entity Description
            let entityDescription = NSEntityDescription.entityForName("Session", inManagedObjectContext: managedContext)
            
            fetchRequest.entity = entityDescription
            fetchRequest.predicate = predicate
            
            let session: NSManagedObject
            
            do {
                let result = try managedContext.executeFetchRequest(fetchRequest)
                if (result.count > 0) {
                    session = result[0] as! NSManagedObject
                } else {
                    session = NSManagedObject(entity: entityDescription!,
                                              insertIntoManagedObjectContext: managedContext)
                }
                
                session.setValue(channel, forKey: "channel_name")
                session.setValue(user_id, forKey: "user_id")
                session.setValue(friend_id, forKey: "friend_id")
                session.setValue(expiry_date, forKey: "expiry_date")
                session.setValue(status, forKey: "status")
                session.setValue(type, forKey: "type")
                session.setValue(id, forKey: "id")
                
                do {
                    try session.managedObjectContext?.save()
                    switch(status.lowercaseString) {
                    case "pending":
                        pendingSessions.append(session)
                    case "requested":
                        requestedSessions.append(session)
                        break
                    case "active":
                        activateSession(session)
                    default:
                        print ("NOT ACTIVE OR PENDING")
                        break
                    }
                } catch let error as NSError {
                    print("Could not save \(error), \(error.userInfo)")
                }
            } catch {
                let fetchError = error as NSError
                print(fetchError)
            }
        }
    }
    
    func activateSession(session: NSManagedObject) {
        if let userIndex = self.requestedSessions.indexOf({ $0.valueForKey("id") as! Int == session.valueForKey("id") as! Int }) {
            self.requestedSessions.removeAtIndex(userIndex)
        }
        self.activeSessions.append(session)
    }
    
    func connectToRequestingWebSocket(session_id: Int) {
        if !client.connected {
            // Retreieve Auth_Token from Keychain
            if let userToken = KeychainAccess.passwordForAccount("Auth_Token", service: "KeyChainService") as String? {
                client.headers = [
                    "Authorization": userToken
                ]
            }
            client.connect()
        }
    
        //let requestChannel = client.create("room_channel_\(friend_id)", identifier: ["id": friend_id])
        requestChannel = client.create("RoomChannel", identifier: ["id": session_id])
        
        requestChannel!.onReceive = { (JSON : AnyObject?, error : ErrorType?) in
            print("Received: \(JSON), Error \(error)")
            if let actionDict = JSON as? [String: AnyObject] {
                let latitude: Double? = actionDict["latitude"] as? Double
                let longitude: Double? = actionDict["longitude"] as? Double
                let name: String = "\(actionDict["first_name"] as? String) \(actionDict["last_name"] as? String)"
                
                if latitude != nil && longitude != nil {
                    if self.mapViewController == nil {
                        print("Can't get Map View Controller")
                    } else {
                        self.mapViewController.locationUpdate(latitude!, longitude: longitude!, friend: name)
                    }
                }
            } else {
                print("Could not cast actionDict as [String: AnyObject]")
            }
        }
    }
    
    func connectToSendingWebSocket(channel_name: String, session_id: Int) {
        if !client.connected {
            // Retreieve Auth_Token from Keychain
            if let userToken = KeychainAccess.passwordForAccount("Auth_Token", service: "KeyChainService") as String? {
                client.headers = [
                    "Authorization": userToken
                ]
            }
            client.connect()
        }
        
        sendChannel = client.create("RoomChannel", identifier: ["id": session_id])
        
        let locValue:CLLocationCoordinate2D = locationManager.location!.coordinate
        sendChannel!["locUpdate"](["latitude": locValue.latitude, "longitude": locValue.longitude])
    }
    
    func connectToSharingWebSocket(channel_name: String, friend_id: Int) {
    }
    
    func displayErrorAlert(message: String) {
        let errorAlert = UIAlertController(title: "", message: message, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil);
        let CancelAction = UIAlertAction(title: "Cancel", style: .Destructive, handler: nil)
        
        errorAlert.addAction(OKAction)
        errorAlert.addAction(CancelAction)
        
        let ranNum = arc4random_uniform(3)
        switch (ranNum) {
        case 0:
            errorAlert.title = errorTitles.woops.rawValue
            break
        case 1:
            errorAlert.title = errorTitles.uhoh.rawValue
            break
        default:
            errorAlert.title = errorTitles.notquite.rawValue
            break
        }
        
        self.presentViewController(errorAlert, animated: true, completion: nil)
    }
    
    func acceptedRequest(id: Int) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("acceptRequest", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPTokenAuth)
        
        httpRequest.HTTPBody = "{\"id\":\"\(id)\"}".dataUsingEncoding(NSUTF8StringEncoding);
        
        // 2. Send the request
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            if error != nil {
                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert(errorMessage as String)
                return
            }
        })
    }
    
    func sendUnsubscribe(session_id: Int) {
        
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("stopTracking", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPTokenAuth)
        
        httpRequest.HTTPBody = "{\"session_id\":\"\(session_id)\"}".dataUsingEncoding(NSUTF8StringEncoding);
        
        // 2. Send the request
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            if error != nil {
                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert(errorMessage as String)
                return
            }
        })
    }
    
    func removeSessionFromCoreData(session_id: Int) {
        //1
        let appDelegate =
            UIApplication.sharedApplication().delegate as! AppDelegate
        
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest = NSFetchRequest()
        
        //Configure predicate
        let predicate : NSPredicate = NSPredicate(format: "id == %@", NSNumber(integer: session_id))
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entityForName("Session", inManagedObjectContext: managedContext)
        
        fetchRequest.entity = entityDescription
        fetchRequest.predicate = predicate
    
        //3
        do {
            let results =
                try managedContext.executeFetchRequest(fetchRequest)
            
            if results.count > 0 {
                for result: AnyObject in results {
                    managedContext.deleteObject(result as! NSManagedObject)
                }
                try managedContext.save()
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
    }
    
    func removeSessionFromLocalArrays(session_id: Int) {
        if let requestedIndex = requestedSessions.indexOf({ $0.valueForKey("id") as! Int == session_id }) {
            requestedSessions.removeAtIndex(requestedIndex)
        }
        
        if let activeIndex = activeSessions.indexOf({ $0.valueForKey("id") as! Int == session_id }) {
            activeSessions.removeAtIndex(activeIndex)
        }
    }
}

private extension UIStoryboard {
    class func mainStoryboard() -> UIStoryboard { return UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()) }
    
    class func controlPanelViewController() -> ControlPanelViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("ControlPanelViewController") as? ControlPanelViewController
    }
    
    class func mapViewController() -> ViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("ViewController") as? ViewController
    }
    
    class func signInViewController() -> SignInViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("SignInViewController") as? SignInViewController
    }
}

extension ContainerViewController: UIGestureRecognizerDelegate {
    
    func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        let gestureIsDraggingFromTopToBottom = (recognizer.velocityInView(view).y > 0)
        let gestureIsDraggingFromBottomToTop = (recognizer.velocityInView(view).y < 0)
        switch(recognizer.state) {
        case .Changed:
            if (currentState == .Visible && gestureIsDraggingFromBottomToTop) {
                recognizer.view!.center.y = recognizer.view!.center.y + recognizer.translationInView(view).y
                recognizer.setTranslation(CGPointZero, inView: view)
            } else if (currentState == .Hidden && gestureIsDraggingFromTopToBottom) {
                recognizer.view!.center.y = recognizer.view!.center.y + recognizer.translationInView(view).y
                recognizer.setTranslation(CGPointZero, inView: view)
            }
        case .Ended:
            if (controlPanelViewController != nil) {
                // animate the side panel open or closed based on whether the view has moved more or less than quarter way
                if gestureIsDraggingFromTopToBottom {
                    if currentState == .Hidden {
                        let hasMovedGreaterThanQuarterWay = recognizer.view!.center.y > -viewHeight + view.bounds.size.height/4
                        animateControlPanel(hasMovedGreaterThanQuarterWay)
                    }
                } else if gestureIsDraggingFromBottomToTop {
                    if currentState == .Visible {
                        let hasMovedGreaterThanQuarterWay = recognizer.view!.center.y < -viewHeight / 4
                        animateControlPanel(hasMovedGreaterThanQuarterWay)
                    }
                }
            }
        default:
            break
        }
    }
}

extension ContainerViewController: ViewControllerDelegate {
    
    func animateControlPanel(shouldExpand: Bool) {
        if (shouldExpand) {
            currentState = .Visible
            animateControlPanelYPosition(0)
        } else {
            animateControlPanelYPosition(-CGRectGetHeight(mapViewController.view.frame)) { finished in
                self.currentState = .Hidden
            }
        }
    }
    
    func animateControlPanelYPosition(targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .CurveEaseInOut, animations: {
            self.controlPanelViewController!.view.frame.origin.y = targetPosition
            }, completion: completion)
    }
}

extension ContainerViewController: SignInViewControllerDelegate {
    func SignedIn() {
        instantiateControlPanelViewController()
        hideContentController(signInViewController, animation: true)
        displayContentController(controlPanelViewController, animation: true)
        if defaults.objectForKey("userLoggedIn") != nil {
            appDelegate.updateData()
        }
    }
}

extension ContainerViewController: ControlPanelViewControllerDelegate {
    func SignedOut() {
        animateControlPanel(false)
        hideContentController(controlPanelViewController, animation: true)
        controlPanelViewController = nil
        displayContentController(signInViewController, animation: true)
    }
    
    func showAddFriendViewController() {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        if (addFriendViewController != nil) {
            hideContentController(controlPanelViewController, animation: true)
            displayContentController(addFriendViewController!, animation: true)
        }
    }
    
    func showNotificationsViewController() {
        notificationsViewController = NotificationsViewController()
        notificationsViewController!.delegate = self
        if (notificationsViewController != nil) {
            hideContentController(controlPanelViewController, animation: true)
            displayContentController(notificationsViewController!, animation: true)
        }
    }
    
    func addFriend(username: String, status: String, selectedCell: FindFriendsCell?) {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        addFriendViewController!.addFriend(username, status: status, selectedCell: nil)
    }
    
    func removeFriend(username: String, selectedCell: FindFriendsCell?) {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        addFriendViewController!.removeFriend(username, selectedCell: nil)
    }
    
    func acceptLocationRequest(sessionDict: [String: AnyObject]) {
        print("Accepted Location Request: \(sessionDict)")
        self.acceptedRequest(sessionDict["id"] as! Int)
        self.saveSessionToCoreData(sessionDict)
        self.connectToSendingWebSocket(sessionDict["channel_name"] as! String, session_id: sessionDict["id"] as! Int)
    }
    
    func sendRequest(type: String, friend_id: Int) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("locRequest", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPTokenAuth)
        
        httpRequest.HTTPBody = "{\"request_type\":\"\(type)\",\"id\":\"\(friend_id)\"}".dataUsingEncoding(NSUTF8StringEncoding);
        
        // 2. Send the request
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            if error != nil {
                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert(errorMessage as String)
                return
            }
            
            do {
                if let responseDict = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? [String: AnyObject] {
                    self.locationRequested(responseDict)
                } else {
                    print("Could not parse response dictionary!")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        })
    }
    
    func unsubscribe(id: Int?, channelType: String) {
        var session_id: Int?
        
        if id == nil {
            session_id = self.currentSession!.valueForKey("id") as? Int
        } else {
            session_id = id
        }
        
        if session_id != nil {
            //1. Remove from local arrays
            self.removeSessionFromLocalArrays(session_id!)
            //2. Remove from core data
            self.removeSessionFromCoreData(session_id!)
        }
        
        switch(channelType.lowercaseString) {
        case "requestchannel":
            if self.requestChannel == nil { return }
            else {
                self.requestChannel!.unsubscribe()
                if session_id != nil {
                    //Send Unsubscribe to server
                    //self.sendUnsubscribe(session_id!)
                }
            }
            break
        case "sendchannel":
            if self.sendChannel == nil { return }
            else { self.sendChannel!.unsubscribe() }
            break
        default:
            break
        }
    }
    
    func getSessionsCount(type: String) -> Int {
        switch (type.lowercaseString) {
        case "active":
            var activeSessions = self.activeSessions.count
            if activeSessions > 0 {
                if sendChannel != nil {
                    activeSessions -= 1
                }
            }
            return activeSessions
        case "requested":
            return self.requestedSessions.count
        case "pending":
            return self.pendingSessions.count
        default:
            return self.cancelledSessions.count
        }
    }
    
    func getSessions(type: String) -> Array<NSManagedObject> {
        switch(type.lowercaseString) {
        case "active":
            return activeSessions
        case "requested":
            return requestedSessions
        case "pending":
            return pendingSessions
        default:
            return cancelledSessions
        }
    }
}

extension ContainerViewController: NotificationsDelegate {
    func hideNotifications() {
        if (notificationsViewController != nil) {
            hideContentController(notificationsViewController!, animation: true)
            displayContentController(controlPanelViewController, animation: true)
            controlPanelViewController.refreshFriendsTV()
        }
    }
}

extension ContainerViewController: AddFriendDelegate {
    func hideAddFriend() {
        if (addFriendViewController != nil) {
            hideContentController(addFriendViewController!, animation: true)
            displayContentController(controlPanelViewController, animation: true)
            controlPanelViewController.refreshFriendsTV()
        }
    }
    
    func updateFriendsTableView() {
        controlPanelViewController.refreshFriendsTV()
    }
}

extension ContainerViewController: CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.count > 0 {
            let location = locations.last!
            if sendChannel != nil {
                sendChannel!["locUpdate"](["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude])
            }
            
            if !isInitialized {
                self.mapViewController.setLocation(location)                
                isInitialized = true
            }
        }
    }
    
    /// Log any errors to the console.
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Error occured: \(error.localizedDescription).")
    }
}
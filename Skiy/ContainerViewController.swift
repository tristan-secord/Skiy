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
        case hidden
        case visible
    }
    
    var currentState = controllerState.hidden
    var controlPanelViewController: ControlPanelViewController!
    var mapViewController: ViewController!
    var signInViewController: SignInViewController!
    var addFriendViewController: AddFriendViewController?
    var notificationsViewController: NotificationsViewController?
    var viewWidth: CGFloat = 0.0
    var viewHeight: CGFloat = 0.0
    var blurView = UIImageView()
    let defaults = UserDefaults.standard
    let appDelegate =
        UIApplication.shared.delegate as! AppDelegate
    let statusBarHeight =
        UIApplication.shared.statusBarFrame.size.height
    let httpHelper = HTTPHelper()
    let sendClient = ActionCableClient(url: URL(string: "ws://immense-forest-45065.herokuapp.com/cable")!)
    let requestClient = ActionCableClient(url: URL(string: "ws://immense-forest-45065.herokuapp.com/cable")!)
    let locationManager = CLLocationManager()
    
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
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 10.0 // Every 10m an event will be fired to update location
            locationManager.startUpdatingLocation()
            locationManager.allowsBackgroundLocationUpdates = false
        }
    
        viewWidth = view.frame.size.width
        viewHeight = view.frame.size.height
        
        //instantiate mapViewController
        mapViewController = UIStoryboard.mapViewController()
        mapViewController.view.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
        mapViewController.delegate = self
        view.addSubview(mapViewController.view)
        addChildViewController(mapViewController)
        mapViewController.didMove(toParentViewController: self)
        
        //instantiate controlPanelViewController
        instantiateControlPanelViewController()
        
        //instantiate signInViewController
        signInViewController = UIStoryboard.signInViewController()
        signInViewController.delegate = self
        signInViewController.view.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
    }
    
    func instantiateControlPanelViewController() {
        controlPanelViewController = UIStoryboard.controlPanelViewController()
        controlPanelViewController.delegate = self
        controlPanelViewController.view.frame = CGRect(x: 0, y: -viewHeight, width: viewWidth, height: viewHeight + 66 + statusBarHeight)
        
        //add Gesture Recognizer to control panel
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ContainerViewController.handlePanGesture(_:)))
        controlPanelViewController!.view.addGestureRecognizer(panGestureRecognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        //try and use single map
        if defaults.object(forKey: "userLoggedIn") == nil {
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
    
    func hideContentController(_ content: UIViewController, animation: Bool) {
        content.willMove(toParentViewController: nil)
        if (animation == true) {
            UIView.animate(withDuration: 0.5, animations: {content.view.alpha = 0.0},
                                       completion: {(value: Bool) in
                                        content.view.removeFromSuperview()
            })
        } else {
            content.view.removeFromSuperview()
        }
        content.removeFromParentViewController()
    }
    
    func displayContentController(_ content: UIViewController, animation: Bool) {
        addChildViewController(content)
        content.view.alpha = 0.0
        UIView.animate(withDuration: 0.5, animations: {content.view.alpha = 1.0},
                                    completion: {(value: Bool) in
                                    self.view.addSubview(content.view)
        })
        content.didMove(toParentViewController: self)
    }
    
    func locationRequested(_ data: [String: AnyObject]) {
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
    
    func shareLocationRequested(_ sendSession: [String: AnyObject], requestSession: [String: AnyObject]) {
        if let requestSessionID = requestSession["id"] as? Int {
            saveSessionToCoreData(sendSession)
            saveSessionToCoreData(requestSession)
            
            connectToRequestingWebSocket(requestSessionID)
            
            if controlPanelViewController != nil {
                controlPanelViewController.updateMap(requestSession)
                if !updateCurrentSession(requestSessionID) {
                    print ("Could not update current session")
                }
            }
            
            self.showSession(requestSession)
        }
    }
    
    func backgroundLocationUpdates() {
        if sendChannel != nil {
            locationManager.allowsBackgroundLocationUpdates = true
        } else {
            locationManager.allowsBackgroundLocationUpdates = false
        }
    }
    
    func allowBackgroundLocationUpdates() {
        locationManager.allowsBackgroundLocationUpdates = true
    }
    
    func showSession(_ data: [String:AnyObject]) {
        if let sessionId = data["id"] as? Int {
            //updateCurrentSession
            _ = self.updateCurrentSession(sessionId)
            
            //Show Map
            if controlPanelViewController != nil {
                print("Updating Map")
                controlPanelViewController.updateMap(data)
            }
            animateControlPanel(false)
        }
    }
    
    func updateCurrentSession(_ session_id: Int) -> Bool {
        if let userIndex = requestedSessions.index(where: { $0.value(forKey: "id") as! Int == session_id }) {
            currentSession = requestedSessions[userIndex]
        } else if let userIndex = activeSessions.index(where: { $0.value(forKey: "id") as! Int == session_id }) {
            currentSession = activeSessions[userIndex]
        } else {
            return false
        }
        
        return true
    }
    
    func saveSessionToCoreData(_ data: [String: AnyObject]) {
        //create an expiry date of 3 hours -> 3 * 60 * 60 (seconds)
        let expiry_date = Date()
        _ = expiry_date.addingTimeInterval(3 * 60 * 60) // GET EXPIRY DATE FROM SERVER!!!
        //save session to core data
        if let channel = data["channel_name"] as? String,
            let user_id = data["user_id"] as? Int,
            let friend_id = data["friend_id"] as? Int,
            let status = data["status"] as? String,
            let type = data["request_type"] as? String,
            let id = data["id"] as? Int{
            
            let appDelegate =
                UIApplication.shared.delegate as! AppDelegate
            
            let managedContext = appDelegate.managedObjectContext
            
            // Initialize Fetch Request
            let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Session")
            
            //Configure predicate
            let predicate : NSPredicate = NSPredicate(format: "id == %@", NSNumber(value: id as Int))
            
            // Create Entity Description
            let entityDescription = NSEntityDescription.entity(forEntityName: "Session", in: managedContext)
            
            fetchRequest.entity = entityDescription
            fetchRequest.predicate = predicate
            
            var session: NSManagedObject
            
            do {
                let result = try managedContext.fetch(fetchRequest)
                if (result.count > 0) {
                    session = result[0] as! NSManagedObject
                } else {
                    session = NSManagedObject(entity: entityDescription!,
                                              insertInto: managedContext)
                }
                
                session.setValue(channel, forKey: "channel_name")
                session.setValue(user_id, forKey: "user_id")
                session.setValue(friend_id, forKey: "friend_id")
                session.setValue(expiry_date, forKey: "expiry_date")
                session.setValue(status, forKey: "status")
                session.setValue(type, forKey: "type")
                session.setValue(id, forKey: "id")
                
                do {
                    print ("saving")
                    try session.managedObjectContext?.save()
                    print("saved")
                    switch(status.lowercased()) {
                    case "pending":
                        pendingSessions.append(session)
                    case "requested":
                        requestedSessions.append(session)
                        break
                    case "active":
                        print("active")
                        activateSession(session)
                        print("finished activating")
                    default:
                        print ("NOT ACTIVE OR PENDING")
                        break
                    }
                    print ("Saved to local variables and core data")
                    controlPanelViewController.refreshFriendsTV()
                    print ("Refreshed Friends TV")
                } catch let error as NSError {
                    print("Could not save \(error), \(error.userInfo)")
                }
            } catch {
                let fetchError = error as NSError
                print(fetchError)
            }
        }
    }
    
    func activateSession(_ session: NSManagedObject) {
        if let userIndex = self.requestedSessions.index(where: { $0.value(forKey: "id") as! Int == session.value(forKey: "id") as! Int }) {
            self.requestedSessions.remove(at: userIndex)
        }
        if let userIndex = self.pendingSessions.index(where: { $0.value(forKey: "id") as! Int == session.value(forKey: "id") as! Int }) {
            self.pendingSessions.remove(at: userIndex)
        }
        self.activeSessions.append(session)
    }
    
    func connectToRequestingWebSocket(_ session_id: Int) {
        if !requestClient.isConnected {
            // Retreieve Auth_Token from Keychain
            if let userToken = KeychainAccess.passwordForAccount("Auth_Token", service: "KeyChainService") as String? {
                requestClient.headers = [
                    "Authorization": userToken
                ]
            }
            requestClient.connect()
        }
    
        requestChannel = requestClient.create("RoomChannel", identifier: ["id": session_id])
        
        self.requestChannel?.onReceive = {(JSON: Any?, error: Error?) in
            print("Received: \(JSON), Error \(error)")
            if let actionDict = JSON as? [String: AnyObject] {
                let latitude: Double? = actionDict["latitude"] as? Double
                let longitude: Double? = actionDict["longitude"] as? Double
                let name: String? = "\(actionDict["first_name"] as? String) \(actionDict["last_name"] as? String)"
                
                if latitude != nil && longitude != nil {
                    if self.mapViewController == nil {
                        print("Can't get Map View Controller")
                    } else {
                        self.mapViewController.locationUpdate(latitude!, longitude: longitude!, friend: name!)
                    }
                }
            } else {
                print("Could not cast actionDict as [String: AnyObject]")
            }
        }
    }
    
    func connectToSendingWebSocket(_ channel_name: String, session_id: Int) {
        if !sendClient.isConnected {
            // Retreieve Auth_Token from Keychain
            if let userToken = KeychainAccess.passwordForAccount("Auth_Token", service: "KeyChainService") as String? {
                sendClient.headers = [
                    "Authorization": userToken
                ]
            }
            sendClient.connect()
        }
        
        sendChannel = sendClient.create("RoomChannel", identifier: ["id": session_id])
        
        let locValue:CLLocationCoordinate2D = locationManager.location!.coordinate
        _ = sendChannel!["locUpdate"](["latitude": locValue.latitude, "longitude": locValue.longitude])
    }
    
    func displayErrorAlert(_ message: String) {
        let errorAlert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default, handler: nil);
        let CancelAction = UIAlertAction(title: "Cancel", style: .destructive, handler: nil)
        
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
        
        self.present(errorAlert, animated: true, completion: nil)
    }
    
    func acceptedRequest(_ id: Int, type: String, requestId: Int?) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("acceptRequest", method: "POST",
                                                  authType: HTTPRequestAuthType.httpTokenAuth)
        if type == "SHARE" {
            httpRequest.httpBody = "{\"id\":\"\(id)\", \"reqId\":\"\(requestId!)\", \"type\":\"\(type)\"}".data(using: String.Encoding.utf8);
        } else {
            httpRequest.httpBody = "{\"id\":\"\(id)\", \"type\":\"\(type)\"}".data(using: String.Encoding.utf8);
        }
        
        // 2. Send the request
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            if error != nil {
                self.displayErrorAlert((error?.localizedDescription)! as String)
                return
            }
        })
    }
    
    func removeSessionFromCoreData(_ session_id: Int) {
        //1
        let appDelegate =
            UIApplication.shared.delegate as! AppDelegate
        
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Session")
        
        //Configure predicate
        let predicate : NSPredicate = NSPredicate(format: "id == %@", NSNumber(value: session_id as Int))
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Session", in: managedContext)
        
        fetchRequest.entity = entityDescription
        fetchRequest.predicate = predicate
    
        //3
        do {
            let results =
                try managedContext.fetch(fetchRequest) as! [NSManagedObject]
            
            if results.count > 0 {
                print("Results: \(results)")
                for result in results {
                    result.setValue("cancelled", forKey: "status")
                    print("Removed result")
                }
                try managedContext.save()
                print ("Saved")
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        print("Removed from core data")
    }
    
    func removeSessionFromLocalArrays(_ session_id: Int) {
        if let activeIndex = activeSessions.index(where: { $0.value(forKey: "id") as! Int == session_id }) {
            cancelledSessions.append(activeSessions[activeIndex])
            activeSessions.remove(at: activeIndex)
        } else if let requestedIndex = requestedSessions.index(where: { $0.value(forKey: "id") as! Int == session_id }) {
            requestedSessions.remove(at: requestedIndex)
        } else if let pendingIndex = pendingSessions.index(where: { $0.value(forKey: "id") as! Int == session_id }) {
            pendingSessions.remove(at: pendingIndex)
        }
        controlPanelViewController.refreshFriendsTV()
    }
    
    func checkCoreDataForSendingSessions() -> Bool {
        let appDelegate =
            UIApplication.shared.delegate as! AppDelegate
        
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Session")
        
        //Configure predicate
        let predicate : NSPredicate = NSPredicate(format: "type == %@", NSString(string: "SEND"))
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Session", in: managedContext)
        
        fetchRequest.entity = entityDescription
        fetchRequest.predicate = predicate

        do {
            let results =
                try managedContext.fetch(fetchRequest)
            
            if results.count > 1 {
                return true
            } else {
                return false
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return false
    }
}

private extension UIStoryboard {
    class func mainStoryboard() -> UIStoryboard { return UIStoryboard(name: "Main", bundle: Bundle.main) }
    
    class func controlPanelViewController() -> ControlPanelViewController? {
        return mainStoryboard().instantiateViewController(withIdentifier: "ControlPanelViewController") as? ControlPanelViewController
    }
    
    class func mapViewController() -> ViewController? {
        return mainStoryboard().instantiateViewController(withIdentifier: "ViewController") as? ViewController
    }
    
    class func signInViewController() -> SignInViewController? {
        return mainStoryboard().instantiateViewController(withIdentifier: "SignInViewController") as? SignInViewController
    }
}

extension ContainerViewController: UIGestureRecognizerDelegate {
    
    func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let gestureIsDraggingFromTopToBottom = (recognizer.velocity(in: view).y > 0)
        let gestureIsDraggingFromBottomToTop = (recognizer.velocity(in: view).y < 0)
        switch(recognizer.state) {
        case .changed:
            if (currentState == .visible && gestureIsDraggingFromBottomToTop) {
                recognizer.view!.center.y = recognizer.view!.center.y + recognizer.translation(in: view).y
                recognizer.setTranslation(CGPoint.zero, in: view)
            } else if (currentState == .hidden && gestureIsDraggingFromTopToBottom) {
                recognizer.view!.center.y = recognizer.view!.center.y + recognizer.translation(in: view).y
                recognizer.setTranslation(CGPoint.zero, in: view)
            }
        case .ended:
            if (controlPanelViewController != nil) {
                // animate the side panel open or closed based on whether the view has moved more or less than quarter way
                if gestureIsDraggingFromTopToBottom {
                    if currentState == .hidden {
                        let hasMovedGreaterThanQuarterWay = recognizer.view!.center.y > -viewHeight + view.bounds.size.height/4
                        animateControlPanel(hasMovedGreaterThanQuarterWay)
                    }
                } else if gestureIsDraggingFromBottomToTop {
                    if currentState == .visible {
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
    
    func animateControlPanel(_ shouldExpand: Bool) {
        if (shouldExpand) {
            currentState = .visible
            animateControlPanelYPosition(0)
        } else {
            animateControlPanelYPosition(-mapViewController.view.frame.height) { finished in
                self.currentState = .hidden
            }
        }
    }
    
    func animateControlPanelYPosition(_ targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions(), animations: {
            self.controlPanelViewController!.view.frame.origin.y = targetPosition
            }, completion: completion)
    }
}

extension ContainerViewController: SignInViewControllerDelegate {
    func SignedIn() {
        instantiateControlPanelViewController()
        hideContentController(signInViewController, animation: true)
        displayContentController(controlPanelViewController, animation: true)
        if defaults.object(forKey: "userLoggedIn") != nil {
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
    
    func addFriend(_ username: String, status: String, selectedCell: FindFriendsCell?) {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        addFriendViewController!.addFriend(username, status: status, selectedCell: nil)
    }
    
    func removeFriend(_ username: String, selectedCell: FindFriendsCell?) {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        addFriendViewController!.removeFriend(username, selectedCell: nil)
    }
    
    func friendRemoved(_ username: String, selectedCell: FindFriendsCell?) {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        addFriendViewController!.friendRemoved(username, selectedCell: selectedCell)
    }
    
    func acceptLocationRequest(_ sessionDict: [String: AnyObject]) {
        self.acceptedRequest(sessionDict["id"] as! Int, type: "REQUEST", requestId: nil)
        
        var acceptedSession: [String: AnyObject] = sessionDict
        acceptedSession["status"] = "active" as AnyObject?
        self.saveSessionToCoreData(acceptedSession)
        
        self.connectToSendingWebSocket(sessionDict["channel_name"] as! String, session_id: sessionDict["id"] as! Int)
    }
    
    func acceptShareRequest(_ sendSession: [String: AnyObject], requestDict requestSession: [String: AnyObject]) {
        self.acceptedRequest(sendSession["id"] as! Int, type: "SHARE", requestId: requestSession["id"] as? Int)
        
        var acceptedSendSession: [String: AnyObject] = sendSession
        acceptedSendSession["status"] = "active" as AnyObject
        self.saveSessionToCoreData(acceptedSendSession)
        
        var acceptedRequestSession: [String: AnyObject] = requestSession
        acceptedRequestSession["status"] = "active" as AnyObject
        self.saveSessionToCoreData(acceptedRequestSession)
        
        print("Accept Share Request ----------")
        print("Sending Session: \(sendSession)")
        print("Requesting Session: \(requestSession)")
        
        self.connectToSendingWebSocket(sendSession["channel_name"] as! String, session_id: sendSession["id"] as! Int)
        self.connectToRequestingWebSocket(requestSession["id"] as! Int)
        
    }
    
    func sendRequest(_ type: String, friend_id: Int) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("locRequest", method: "POST",
                                                  authType: HTTPRequestAuthType.httpTokenAuth)
        
        httpRequest.httpBody = "{\"request_type\":\"\(type)\",\"id\":\"\(friend_id)\"}".data(using: String.Encoding.utf8);
        
        // 2. Send the request
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            if error != nil {
                self.displayErrorAlert((error?.localizedDescription)! as String)
                return
            }
            
            do {
                if let responseDict = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                    if type == "SHARE" {
                        if let requestSession = responseDict["request_session"] as? [String: AnyObject], let sendSession = responseDict["send_session"] as? [String: AnyObject] {
                            self.shareLocationRequested(sendSession, requestSession: requestSession)
                        }
                    } else {
                        self.locationRequested(responseDict)
                    }
                } else {
                    print("Could not parse response dictionary!")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        })
    }
    
    func unsubscribe(_ id: Int?, channelType: String) {
        var session_id: Int?
        
        if id == nil {
            print ("nil id")
            session_id = self.currentSession!.value(forKey: "id") as? Int
            print ("Current session Id: \(session_id)")
        } else {
            session_id = id
            print("Session id: \(session_id)")
        }
        
        print("Channel Type: \(channelType)")
        
        switch(channelType.lowercased()) {
        case "requestchannel":
            if self.requestChannel == nil { return }
            else {
                print("\(self.requestChannel)")
                self.requestChannel!.unsubscribe()
                self.requestChannel = nil
            }
            break
        case "sendchannel":
            if self.sendChannel == nil { return }
            else {
                print("\(self.sendChannel)")
                self.sendChannel!.unsubscribe()
                self.sendChannel = nil
            }
            break
        default:
            break
        }
        
        if session_id != nil {
            print("Session id: \(session_id)")
            //1. Remove from local arrays
            self.removeSessionFromLocalArrays(session_id!)
            //2. Remove from core data
            self.removeSessionFromCoreData(session_id!)
        }
    }
    
    func getSessionsCount(_ type: String) -> Int {
        switch (type.lowercased()) {
        case "active":
            return self.activeSessions.count
        case "requested":
            return self.requestedSessions.count
        case "pending":
            return self.pendingSessions.count
        default:
            return self.cancelledSessions.count
        }
    }
    
    func getSessions(_ type: String) -> Array<NSManagedObject> {
        switch(type.lowercased()) {
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
    
    func removeReceiver(session: NSManagedObject) {
        let session_id = session.value(forKey: "id") as? Int
        
        //1. If no more 'SEND' sessions in Core Data - unsubscribe from sendChannel
        if (!self.checkCoreDataForSendingSessions()) {
            self.unsubscribe(session_id, channelType: "sendchannel")
        } else {
            //2. Remove session with session_id from Core Data
            if session_id != nil {
                //1. Remove from local arrays
                self.removeSessionFromLocalArrays(session_id!)
                //2. Remove from core data
                self.removeSessionFromCoreData(session_id!)
            }
            
            //3. Send data to server to update server data
            self.removeReceiverFromServer(session_id!)
        }
    }
    
    func removeReceiverFromServer(_ session_id: Int) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("removeReceiver", method: "POST",
                                                  authType: HTTPRequestAuthType.httpTokenAuth)
        
        httpRequest.httpBody = "{\"session_id\":\"\(session_id)\"}".data(using: String.Encoding.utf8);
        
        // 2. Send the request
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            if error != nil {
                self.displayErrorAlert((error?.localizedDescription)! as String)
                return
            }
        })
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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.count > 0 {
            let location = locations.last!
            if sendChannel != nil {
                _ = sendChannel!["locUpdate"](["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude])
            }
            
            if !isInitialized {
                self.mapViewController.setLocation(location)                
                isInitialized = true
            }
        }
    }
    
    /// Log any errors to the console.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error occured: \(error.localizedDescription).")
    }
}

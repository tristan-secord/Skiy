//
//  AppDelegate.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-04-09.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var httpHelper = HTTPHelper()
    let defaults = NSUserDefaults.standardUserDefaults()
    var badgeCount = 0
    typealias Payload = [String: AnyObject]
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "uk.co.plymouthsoftware.core_data" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("SkiyData", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("Skiy.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as! NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    
    func setStatusBarBackgroundColor(color: UIColor) {
        
        guard  let statusBar = UIApplication.sharedApplication().valueForKey("statusBarWindow")?.valueForKey("statusBar") as? UIView else {
            return
        }
        
        statusBar.backgroundColor = color
    }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        UIApplication.sharedApplication().applicationIconBadgeNumber = badgeCount
        
        self.setStatusBarBackgroundColor(UIColor.blackColor())
        
        //Register for push notifications
        let notificationTypes: UIUserNotificationType = [UIUserNotificationType.Alert, UIUserNotificationType.Badge, UIUserNotificationType.Sound]
        let pushNotificationSettings = UIUserNotificationSettings(forTypes: notificationTypes, categories: nil)
        application.registerUserNotificationSettings(pushNotificationSettings)
        application.registerForRemoteNotifications()
        
        
        //Set launch screen
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        let containerViewController = ContainerViewController()
        window!.rootViewController = containerViewController
        window!.makeKeyAndVisible()
        
        if let notification = launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey] as? [String: AnyObject] {
            let aps = notification["aps"] as! [String: AnyObject]
            switch (aps["category"] as! String) {
            case "SIGNOUT":
                    signOutFromPushNotification(aps)
                break
            default:
                //PULL ALL DATA INTO CORE DATA
                //UPDATE EVERYTHING!!!
                //BRING TO NOTIFICATIONS PAGE
                break
            }
        }
        
        return true
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let deviceTokenString = String(format: "\(deviceToken)")
        defaults.setObject(deviceTokenString, forKey: "deviceToken")
        defaults.synchronize()
    }

    func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
        if notificationSettings.types != .None {
            application.registerForRemoteNotifications()
        }
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        print("Could not register for push notifications")
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        let aps = userInfo["aps"] as! [String: AnyObject]
        let custom_data = userInfo["custom_data"] as? [String: AnyObject]
        
        badgeCount -= 1
        UIApplication.sharedApplication().applicationIconBadgeNumber = badgeCount
        
        switch (aps["category"] as! String) {
        case "SIGNOUT":
            //first check if user is even logged in
            signOutFromPushNotification(aps)
            break
        case "FRIEND_REQUEST":
            showFriendRequest(aps, custom_data: custom_data!)
            break
        case "REQUEST_LOCATION":
            showLocationRequest(aps, custom_data: custom_data!)
            break
        case "ACCEPTED":
            activateRequest(aps, custom_data: custom_data!)
            break
        case "UNSUBSCRIBE_REQUESTER":
            if let session_id = custom_data!["session_id"] as? Int {
                unsubscribe(aps, session_id: session_id, channel: "RequestChannel")
            }
            break
        case "UNSUBSCRIBE_SENDER":
            if let session_id = custom_data!["session_id"] as? Int {
                unsubscribe(aps, session_id: session_id, channel: "SendChannel")
            }
            break
        default:
            break
        }
    }
    
    func getControlPanelViewController() -> ControlPanelViewController? {
        if let containerVC = self.window?.rootViewController as? ContainerViewController {
            let viewControllers = containerVC.childViewControllers
            for viewController in viewControllers {
                if let controlPanelVC = viewController as? ControlPanelViewController {
                    return controlPanelVC
                }
            }
        }
        return nil
    }
    
    func unsubscribe(aps: [String: AnyObject], session_id: Int, channel: String) {
        var alert : UIAlertController
        
        switch (channel.lowercaseString) {
        case "sendchannel":
            alert = UIAlertController(title: "Unsubscribed", message: "\(aps["alert"] as! String)", preferredStyle: .Alert)
            break
        case "requestchannel":
            alert = UIAlertController(title: "Unsubscribed", message: "\(aps["alert"] as! String) ", preferredStyle: .Alert)
            break
        default:
            alert = UIAlertController(title: "Unsubscribed", message:  "\(aps["alert"] as! String)", preferredStyle: .Alert)
            break
        }
        if let controlPanelVC = self.getControlPanelViewController() as ControlPanelViewController! {
            controlPanelVC.delegate?.unsubscribe(session_id, channelType: channel)
        }
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(OKAction)
        self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    func activateRequest(aps: [String: AnyObject], custom_data: [String: AnyObject]) {
        if let containerVC = self.window?.rootViewController as? ContainerViewController {
            containerVC.saveSessionToCoreData(custom_data)
        } else { print ("Could not get container view controller") }
        
        let alert = UIAlertController(title: "Request Accepted", message: "\(aps["alert"] as! String)", preferredStyle: .Alert)
        let showAction = UIAlertAction(title: "Show", style: .Default) { action in
            if let containerVC = self.window?.rootViewController as? ContainerViewController {
                containerVC.showSession(custom_data)
            } else { print("Could not get container view controller") }
        }
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(OKAction)
        alert.addAction(showAction)
        self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    func showLocationRequest(aps: [String: AnyObject], custom_data: [String: AnyObject]) {
        let alert = UIAlertController(title: "Requesting Location", message: "\(aps["alert"] as! String)", preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "Accept", style: .Default) { action in
            if let controlPanelVC = self.getControlPanelViewController() as ControlPanelViewController! {
                controlPanelVC.delegate?.acceptLocationRequest(custom_data)
            } else {
                print ("Could not get control panel")
            }
        }
        let cancelAction = UIAlertAction(title: "Not Now", style: .Cancel, handler: nil)
        alert.addAction(OKAction)
        alert.addAction(cancelAction)
        self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    func showFriendRequest(aps: [String: AnyObject], custom_data: [String: AnyObject]) {
        //save to core data tableview/friends as "pending"
        let newFriend: Array<Payload> = [custom_data]
        self.saveFriendsToCoreData("pending", friendArray: newFriend)
        
        //Show alert dialog
        let alert = UIAlertController(title: "Friend Request", message: "\(aps["alert"] as! String)", preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "Accept", style: .Default) { action in
            //sign them out
            if let controlPanelVC = self.getControlPanelViewController() as ControlPanelViewController! {
                controlPanelVC.delegate?.addFriend(custom_data["username"] as! String, status: "pending", selectedCell: nil)
                controlPanelVC.refreshFriendsTV()
            } else {
                print("Could not get ControlPanelVC")
                let controlPanelVC = ControlPanelViewController()
                controlPanelVC.delegate?.addFriend(custom_data["username"] as! String, status: "pending", selectedCell: nil)
                controlPanelVC.refreshFriendsTV()
            }
        }
        let cancelAction = UIAlertAction(title: "Not Now", style: .Cancel, handler: nil)
        alert.addAction(OKAction)
        alert.addAction(cancelAction)
        self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    func signOutFromPushNotification(aps: [String: AnyObject]) {
        //Show alert dialog
        let alert = UIAlertController(title: "Friend Request", message: "\(aps["alert"] as! String)", preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default) { action in
            //sign them out
            if let controlPanelVC = self.getControlPanelViewController() as ControlPanelViewController! {
                if (controlPanelVC.friendsTable != nil) {
                    controlPanelVC.signOut()
                }
            } else {
                print("Could not get ControlPanelVC")
                let controlPanelVC = ControlPanelViewController()
                controlPanelVC.signOut()
                //****************************************** Not sure if this will work ********************************
                //clear Core Data and defaults logged in flag here
                //show sign in page
                //******************************************************************************************************
            }
        }
        alert.addAction(OKAction)
        self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        if defaults.objectForKey("userLoggedIn") != nil {
            updateData()
        }
    }
    
    func updateData() {
        //LOAD FRIEND DATA FROM SERVER
        let managedContext = managedObjectContext
        
        //2
        let fetchRequest = NSFetchRequest(entityName: "Friend")
        
        //3
        do {
            let results =
                try managedContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
            
            var httpBody: String = "{\"data_refresh\":["
            for i in 0 ..< results.count {
                //create HTTP Body
                if (i != 0) { httpBody = "\(httpBody)," }
                let person = results[i]
                let id = person.valueForKey("id")!
                let updated_at = person.valueForKey("updated_at")!
                httpBody = "\(httpBody){\"id\":\"\(id)\",\"updated_at\":\"\(updated_at)\"}"
            }
            httpBody = "\(httpBody)]}"
                    
            getFriends(httpBody)
            
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
    }
    
    func getFriends(httpBody : String) {
        // Create HTTP request and set request Body
        let httpRequest = httpHelper.buildRequest("checkOldData", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPTokenAuth)
        
        httpRequest.HTTPBody = httpBody.dataUsingEncoding(NSUTF8StringEncoding);
        
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            // Display error
            if error != nil {
                return
            }
            
            do {
                if let responseDict = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
                    //update data in CoreData
                    self.updateFriends(responseDict)
                } else {
                    print("Could not parse response dictionary!")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        })
    }
    
    func updateFriends(json: NSDictionary) {
        if let pendingFriends = json["pending"] as? Array<Payload>! {
            saveFriendsToCoreData("pending", friendArray: pendingFriends)
        }
        
        if let requestedFriends = json["requested"] as? Array<Payload>! {
            saveFriendsToCoreData("requested", friendArray: requestedFriends)
        }
        
        if let friends = json["friends"] as? Array<Payload>! {
            saveFriendsToCoreData("friends", friendArray: friends)
        }
        
        
        if let containerVC = window?.rootViewController as? ContainerViewController {
            let viewControllers = containerVC.childViewControllers
            for viewController in viewControllers {
                if let controlPanelVC = viewController as? ControlPanelViewController {
                    if (controlPanelVC.friendsTable != nil) {
                        controlPanelVC.refreshFriendsTV()
                    }
                }
            }
        }
    }
    
    func saveFriendsToCoreData(friendStatus: String, friendArray: Array<Payload>!) {
        for i in 0 ..< friendArray.count {
            let item = friendArray[i],
            firstName = item["first_name"] as? String,
            lastName = item["last_name"] as? String,
            username = item["username"] as? String,
            status = friendStatus,
            id = item["id"] as? Int,
            updated_at = NSDate()
            
            
            //Update Record if in Core Data or Save if not in Core Data
            let appDelegate =
                UIApplication.sharedApplication().delegate as! AppDelegate
            
            let managedContext = appDelegate.managedObjectContext
            
            // Initialize Fetch Request
            let fetchRequest = NSFetchRequest()
            
            // Create Entity Description
            let entityDescription = NSEntityDescription.entityForName("Friend", inManagedObjectContext: managedContext)
            
            //Configure predicate
            let predicate : NSPredicate = NSPredicate(format: "id == %@", NSNumber(integer: id!))
            
            // Configure Fetch Request
            fetchRequest.entity = entityDescription
            fetchRequest.predicate = predicate
            
            var friend : NSManagedObject
        
            do {
                let result = try managedContext.executeFetchRequest(fetchRequest)
                if (result.count > 0) {
                    friend = result[0] as! NSManagedObject
                    
                    friend.setValue(status, forKey: "status")
                    friend.setValue(updated_at, forKey: "updated_at")
                } else {
                    friend = NSManagedObject(entity: entityDescription!,
                                                 insertIntoManagedObjectContext: managedContext)
                    friend.setValue(firstName, forKey: "first_name")
                    friend.setValue(lastName, forKey: "last_name")
                    friend.setValue(username, forKey: "username")
                    friend.setValue(status, forKey: "status")
                    friend.setValue(id, forKey: "id")
                    friend.setValue(updated_at, forKey: "updated_at")
                }
                
                do {
                    try friend.managedObjectContext?.save()
                } catch let error as NSError {
                    print("Could not save \(error), \(error.userInfo)")
                }
                
            } catch {
                let fetchError = error as NSError
                print(fetchError)
            }
        }
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        self.saveContext()
    }
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
}


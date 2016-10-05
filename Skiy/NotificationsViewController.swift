//
//  NotificationsViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-09-14.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import Foundation
import CoreData
import EventKit

protocol NotificationsDelegate {
    func hideNotifications()
    func updateFriendsTableView()
}

class Notifications {
    var id : Int
    var category : String = ""
    var payload : String = ""
    var expiry : NSDate
    var created_on : NSDate
    
    init (_ id: Int, category: String, payload: String, expiry:NSDate, created_on: NSDate) {
        self.id = id
        self.category = category
        self.payload = payload
        self.expiry = expiry
        self.created_on = created_on
    }
}

class NotificationsViewController: UIViewController {
    @IBOutlet weak var notificationsTable: UITableView!
    @IBOutlet weak var notificationsPrompt: UIView!
    
    
    
    var httpHelper = HTTPHelper()
    var delegate: NotificationsDelegate?
    var notifications = [NSManagedObject]?()
    typealias Payload = [String: AnyObject]
    var timer: NSTimer? = nil
    let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewWidth = view.frame.size.width
        let viewHeight = view.frame.size.height
        
        //instantiate search panel
        let notificationsPanel = UINib(nibName: "Notifications", bundle: nil).instantiateWithOwner(self, options: nil)[0] as! UIView
        notificationsPanel.frame = CGRectMake(0, 0, viewWidth, viewHeight)
        view.layer.shadowOpacity = 0.8
        
        //Adding Blur Effect
        let blurEffect = UIBlurEffect(style: .Dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRectMake(0, 0, viewWidth, viewHeight)
        view.insertSubview(blurView, atIndex: 0)
        
        //add searchpanel ontop
        view.addSubview(notificationsPanel)
        
        //hide table view and set self to delegate
        notificationsTable.hidden = true
        notificationsPrompt.hidden = false

        notificationsTable.delegate = self
        notificationsTable.dataSource = self
        
        notificationsTable.registerNib(UINib(nibName: "NotificationCell", bundle: nil), forCellReuseIdentifier: "NotificationCell")
        
        
        //load Core Data to local variable notifications
        notifications = self.loadCoreData()
        //immediately show them on TV
        notificationsTable.reloadData()
    }
    
    func loadCoreData() -> [NSManagedObject]? {
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest = NSFetchRequest()
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entityForName("Notification", inManagedObjectContext: managedContext)
        
        // Configure Fetch Request
        fetchRequest.entity = entityDescription
        
        do {
            let result = try managedContext.executeFetchRequest(fetchRequest)
            return (result as? [NSManagedObject])!
        } catch {
            let fetchError = error as NSError
            print(fetchError)
        }
        
        return nil
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.sharedApplication().applicationIconBadgeNumber = 1
        self.getNewData()
        
        //Add expiry counter (decreasing)
        timer = NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: #selector(updateExpiry), userInfo: nil, repeats: true)
        timer!.fire()
    }
    
    func getNewData() {
        if UIApplication.sharedApplication().applicationIconBadgeNumber > 0 {
            self.getNotifications()
            UIApplication.sharedApplication().applicationIconBadgeNumber = 0
        }
    }
    
    func updateExpiry() {
        notificationsTable.reloadData()
    }
    
    func getNotifications() {
        // Create HTTP request and set request Body
        let httpRequest = httpHelper.buildRequest("getNotifications", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPTokenAuth)
        
        let httpBody = "{\"badge_count\":\"\(UIApplication.sharedApplication().applicationIconBadgeNumber)\"}"
        
        httpRequest.HTTPBody = httpBody.dataUsingEncoding(NSUTF8StringEncoding);
        
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            // Display error
            if error != nil {
                return
            }
            
            do {
                if let responseDict = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
                    //update data in CoreData
                    self.updateNotifications(responseDict)
                } else {
                    print("Could not parse response dictionary!")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        })
    }
    
    //save to core data and to notifications array
    func updateNotifications(json: NSDictionary) {
        let managedContext = appDelegate.managedObjectContext
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entityForName("Notification", inManagedObjectContext: managedContext)
        
        if let newNotifications = json["notifications"] as? Array<Payload>! {
            if newNotifications.count > 0 {
                for i in 0..<newNotifications.count {
                    let item = newNotifications[i],
                    id = item["sender_id"] as? Int,
                    category = item["category"] as? String,
                    payload = item["payload"] as? String,
                    expiryString = item["expiry"] as? String,
                    createdString = item["created_at"] as? String
                    
                    //IF NEED TO ADD TIME ZONE INFO TO DATE FORMATTER HERE
                    let dateFormatter = NSDateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    
                    let expiry: NSDate?
                    if expiryString != nil {
                        expiry = dateFormatter.dateFromString(expiryString!)! as NSDate
                    } else {
                        expiry = nil
                    }
                    
                    let created: NSDate?
                    if createdString != nil {
                        created = dateFormatter.dateFromString(createdString!)! as NSDate
                    } else {
                        created = nil
                    }
                    
                    //save to CoreData
                    let notification = NSManagedObject(entity: entityDescription!,
                                                       insertIntoManagedObjectContext: managedContext)
                    notification.setValue(id, forKey: "id")
                    notification.setValue(category, forKey: "category")
                    notification.setValue(payload, forKey: "payload")
                    notification.setValue(expiry!, forKey: "expiry")
                    notification.setValue(created!, forKey: "created")
                    
                    do {
                        try notification.managedObjectContext?.save()
                    } catch let error as NSError {
                        print("Could not save \(error), \(error.userInfo)")
                    }
                    
                    //update Local Variable
                    notifications!.append(notification)
                }
                notificationsTable.reloadData()
                
                for i in 0..<newNotifications.count {
                    let cell = notificationsTable.cellForRowAtIndexPath(NSIndexPath(forRow: i, inSection: 0)) as! NotificationCell
                    cell.newNotificationBubble.hidden = false
                    cell.newNotificationBubble.layer.cornerRadius = 5.0
                    cell.newNotificationBubble.backgroundColor = Colors.colorWithHexString(Colors.babyBlue())
                }
            }
        }
    }

    func getUser(notification: NSManagedObject) -> NSManagedObject? {
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest = NSFetchRequest()
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entityForName("Friend", inManagedObjectContext: managedContext)
        let predicate : NSPredicate = NSPredicate(format: "id == \(notification.valueForKey("id") as! Int)")
        
        // Configure Fetch Request
        fetchRequest.entity = entityDescription
        fetchRequest.predicate = predicate
        
        do {
            var result = try managedContext.executeFetchRequest(fetchRequest)
            result = (result as? [NSManagedObject])!
            if result.count > 0 { return result[0] as? NSManagedObject }
        } catch {
            let fetchError = error as NSError
            print(fetchError)
        }
        return nil
    }
    
    func getExpiration(notification: NSManagedObject) -> String {
        let expiry = notification.valueForKey("expiry") as! NSDate
        let currentDate = NSDate()
        let Calendar = NSCalendar.currentCalendar()
        
        let hourMinute: NSCalendarUnit = [.Hour, .Minute]
        let hoursToExpire = Calendar.components(hourMinute, fromDate: currentDate, toDate: expiry, options: [])
        let expiryString = "\(hoursToExpire.hour)h \(hoursToExpire.minute)m"
        return expiryString
    }
    
    @IBAction func donePressed(sender: UIButton) {
        if timer != nil {
            timer!.invalidate()
            timer = nil
        }
        delegate?.hideNotifications()
    }
    
    @IBAction func refreshPressed(sender: UIButton) {
        self.getNewData()
    }
    
}

extension NotificationsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if notifications!.count <= 0 {
            notificationsTable.hidden = false
            notificationsPrompt.hidden = false
        } else {
            notificationsTable.hidden = false
            notificationsPrompt.hidden = true
        }
        return notifications!.count
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: NotificationCell = tableView.dequeueReusableCellWithIdentifier("NotificationCell", forIndexPath: indexPath) as! NotificationCell
        
        cell.newNotificationBubble.hidden = true
        
        //sort notifications
        notifications!.sortInPlace({ ($0.valueForKey("created") as! NSDate).compare($1.valueForKey("created") as! NSDate) == NSComparisonResult.OrderedDescending })
        
        if notifications!.count > 0 {
            let notification: NSManagedObject = notifications![indexPath.row]
            if let user : NSManagedObject = self.getUser(notification) {
                //Category
                var category = notification.valueForKey("category") as! String
                category = category.stringByReplacingOccurrencesOfString("_", withString: " ")
                
                //Expiration Date
                var expiryString: String = "Expired"
                let expiry = notification.valueForKey("expiry") as? NSDate
                if expiry == nil {
                    expiryString = "Expired"
                } else if expiry!.compare(NSDate()) == NSComparisonResult.OrderedDescending {
                    expiryString = self.getExpiration(notification)
                } else {
                    expiryString = "Expired"
                }
                
                //User info
                let firstName = user.valueForKey("first_name") as! String
                let lastName = user.valueForKey("last_name") as! String
                
                //set up cell
                cell.senderName.text! = "\(firstName) \(lastName)"
                cell.notificationCategory.text! = "\(category)"
                cell.notificationExpiry.text! = "Expires: \(expiryString)"
                if (expiryString == "Expired") {
                    cell.notificationExpiry.text! = "\(expiryString)"
                    cell.senderName.textColor = UIColor.lightGrayColor()
                    cell.notificationExpiry.textColor = UIColor.redColor()
                    cell.notificationCategory.textColor = UIColor.lightGrayColor()
                } else {
                    cell.senderName.textColor = UIColor.whiteColor()
                    cell.notificationExpiry.textColor = UIColor.lightGrayColor()
                    cell.notificationCategory.textColor = Colors.colorWithHexString(Colors.babyBlue())
                }
            }
        }
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60
    }
    
}
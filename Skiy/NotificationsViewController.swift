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
    var expiry : Date
    var created_on : Date
    
    init (_ id: Int, category: String, payload: String, expiry:Date, created_on: Date) {
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
    var notifications : [NSManagedObject]? = nil
    typealias Payload = [String: AnyObject]
    var timer: Timer? = nil
    let appDelegate =
        UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewWidth = view.frame.size.width
        let viewHeight = view.frame.size.height
        
        //instantiate search panel
        let notificationsPanel = UINib(nibName: "Notifications", bundle: nil).instantiate(withOwner: self, options: nil)[0] as! UIView
        notificationsPanel.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
        view.layer.shadowOpacity = 0.8
        
        //Adding Blur Effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
        view.insertSubview(blurView, at: 0)
        
        //add searchpanel ontop
        view.addSubview(notificationsPanel)
        
        //hide table view and set self to delegate
        notificationsTable.isHidden = true
        notificationsPrompt.isHidden = false

        notificationsTable.delegate = self
        notificationsTable.dataSource = self
        
        notificationsTable.register(UINib(nibName: "NotificationCell", bundle: nil), forCellReuseIdentifier: "NotificationCell")
        
        
        //load Core Data to local variable notifications
        notifications = self.loadCoreData()
        //immediately show them on TV
        notificationsTable.reloadData()
    }
    
    func loadCoreData() -> [NSManagedObject]? {
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Notification")

        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Notification", in: managedContext)
        
        // Configure Fetch Request
        fetchRequest.entity = entityDescription
        
        do {
            let result = try managedContext.fetch(fetchRequest)
            return (result as? [NSManagedObject])!
        } catch {
            let fetchError = error as NSError
            print(fetchError)
        }
        
        return nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.applicationIconBadgeNumber = 1
        self.getNewData()
        
        //Add expiry counter (decreasing)
        timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(updateExpiry), userInfo: nil, repeats: true)
        timer!.fire()
    }
    
    func getNewData() {
        if UIApplication.shared.applicationIconBadgeNumber > 0 {
            self.getNotifications()
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    func updateExpiry() {
        notificationsTable.reloadData()
    }
    
    func getNotifications() {
        // Create HTTP request and set request Body
        let httpRequest = httpHelper.buildRequest("getNotifications", method: "POST",
                                                  authType: HTTPRequestAuthType.httpTokenAuth)
        
        let httpBody = "{\"badge_count\":\"\(UIApplication.shared.applicationIconBadgeNumber)\"}"
        
        httpRequest.httpBody = httpBody.data(using: String.Encoding.utf8);
        
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            // Display error
            if error != nil {
                return
            }
            
            do {
                if let responseDict = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary {
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
    func updateNotifications(_ json: NSDictionary) {
        let managedContext = appDelegate.managedObjectContext
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Notification", in: managedContext)
        
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
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    
                    let expiry: Date?
                    if expiryString != nil {
                        expiry = dateFormatter.date(from: expiryString!)! as Date
                    } else {
                        expiry = nil
                    }
                    
                    let created: Date?
                    if createdString != nil {
                        created = dateFormatter.date(from: createdString!)! as Date
                    } else {
                        created = nil
                    }
                    
                    //save to CoreData
                    let notification = NSManagedObject(entity: entityDescription!,
                                                       insertInto: managedContext)
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
                    let cell = notificationsTable.cellForRow(at: IndexPath(row: i, section: 0)) as! NotificationCell
                    cell.newNotificationBubble.isHidden = false
                    cell.newNotificationBubble.layer.cornerRadius = 5.0
                    cell.newNotificationBubble.backgroundColor = Colors.colorWithHexString(Colors.babyBlue())
                }
            }
        }
    }

    func getUser(_ notification: NSManagedObject) -> NSManagedObject? {
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Friend")

        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Friend", in: managedContext)
        let predicate : NSPredicate = NSPredicate(format: "id == \(notification.value(forKey: "id") as! Int)")
        
        // Configure Fetch Request
        fetchRequest.entity = entityDescription
        fetchRequest.predicate = predicate
        
        do {
            var result = try managedContext.fetch(fetchRequest)
            result = (result as? [NSManagedObject])!
            if result.count > 0 { return result[0] as? NSManagedObject }
        } catch {
            let fetchError = error as NSError
            print(fetchError)
        }
        return nil
    }
    
    func getExpiration(_ notification: NSManagedObject) -> String {
        let expiry = notification.value(forKey: "expiry") as! Date
        let currentDate = Date()
        let Calendar = Foundation.Calendar.current
        
        let hourMinute: NSCalendar.Unit = [.hour, .minute]
        let hoursToExpire = (Calendar as NSCalendar).components(hourMinute, from: currentDate, to: expiry, options: [])
        let expiryString = "\(hoursToExpire.hour)h \(hoursToExpire.minute)m"
        return expiryString
    }
    
    @IBAction func donePressed(_ sender: UIButton) {
        if timer != nil {
            timer!.invalidate()
            timer = nil
        }
        delegate?.hideNotifications()
    }
    
    @IBAction func refreshPressed(_ sender: UIButton) {
        self.getNewData()
    }
    
}

extension NotificationsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if notifications!.count <= 0 {
            notificationsTable.isHidden = false
            notificationsPrompt.isHidden = false
        } else {
            notificationsTable.isHidden = false
            notificationsPrompt.isHidden = true
        }
        return notifications!.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: NotificationCell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! NotificationCell
        
        cell.newNotificationBubble.isHidden = true
        
        //sort notifications
        notifications!.sort(by: { ($0.value(forKey: "created") as! Date).compare($1.value(forKey: "created") as! Date) == ComparisonResult.orderedDescending })
        
        if notifications!.count > 0 {
            let notification: NSManagedObject = notifications![(indexPath as NSIndexPath).row]
            if let user : NSManagedObject = self.getUser(notification) {
                //Category
                var category = notification.value(forKey: "category") as! String
                category = category.replacingOccurrences(of: "_", with: " ")
                
                //Expiration Date
                var expiryString: String = "Expired"
                let expiry = notification.value(forKey: "expiry") as? Date
                if expiry == nil {
                    expiryString = "Expired"
                } else if expiry!.compare(Date()) == ComparisonResult.orderedDescending {
                    expiryString = self.getExpiration(notification)
                } else {
                    expiryString = "Expired"
                }
                
                //User info
                let firstName = user.value(forKey: "first_name") as! String
                let lastName = user.value(forKey: "last_name") as! String
                
                //set up cell
                cell.senderName.text! = "\(firstName) \(lastName)"
                cell.notificationCategory.text! = "\(category)"
                cell.notificationExpiry.text! = "Expires: \(expiryString)"
                if (expiryString == "Expired") {
                    cell.notificationExpiry.text! = "\(expiryString)"
                    cell.senderName.textColor = UIColor.lightGray
                    cell.notificationExpiry.textColor = UIColor.red
                    cell.notificationCategory.textColor = UIColor.lightGray
                } else {
                    cell.senderName.textColor = UIColor.white
                    cell.notificationExpiry.textColor = UIColor.lightGray
                    cell.notificationCategory.textColor = Colors.colorWithHexString(Colors.babyBlue())
                }
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
}

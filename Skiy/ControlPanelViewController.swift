    //
    //  ControlPanelViewController.swift
    //  Skiy
    //
    //  Created by Tristan Secord on 2016-05-21.
    //  Copyright © 2016 Tristan Secord. All rights reserved.
    //
    
    import UIKit
    import CoreData
    import FloatingActionSheetController
    
    protocol ControlPanelViewControllerDelegate {
        func SignedOut()
        func showAddFriendViewController()
        func showNotificationsViewController()
        func addFriend(username: String, status: String, selectedCell: FindFriendsCell?)
        func removeFriend(username: String, selectedCell: FindFriendsCell?)
        func acceptLocationRequest(responseDict: [String: AnyObject])
        func sendRequest(type: String, friend_id: Int)
        func updateFriendsTableView()
        func unsubscribe(session_id: Int?, channelType: String)
        func getSessionsCount(type: String) -> Int
        func getSessions(type: String) -> Array<NSManagedObject>
    }
    
    class ControlPanelViewController: UIViewController {
        
        @IBOutlet weak var friendsTable: UITableView!
        @IBOutlet weak var nameLabel: UILabel!
        @IBOutlet weak var statusLabel: UILabel!
        @IBOutlet weak var dragPill: UIView!
        @IBOutlet weak var friendsPrompt: UIView!
        @IBOutlet weak var friendsPromptMessage: UILabel!
        @IBOutlet weak var cancelButton: UIButton!
        @IBOutlet weak var removeMarkersButton: UIButton!
        @IBOutlet weak var tableViewControl: UISegmentedControl!
        
        
        var delegate: ControlPanelViewControllerDelegate?
        var numberOfDots = 3
        var friends = [NSManagedObject]()
        typealias Payload = [String: AnyObject]
        var httpHelper = HTTPHelper()
        let defaults = NSUserDefaults.standardUserDefaults()
        let appDelegate =
            UIApplication.sharedApplication().delegate as! AppDelegate
        let statusBarHeight =
            UIApplication.sharedApplication().statusBarFrame.size.height
        
        var activeColor: UIColor = Colors.colorWithHexString("#4CD964") // green
        var pendingColor: UIColor = Colors.colorWithHexString("#8E8E93") // gray
        var requestColor: UIColor = Colors.colorWithHexString("#5AC8FB") // blue
        
        enum mapState {
            case homeMap
            case trackingMap
        }
        var currentMap: mapState = mapState.homeMap
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            let viewWidth = view.frame.size.width
            let viewHeight = view.frame.size.height
            
            //instantiate control panel
            let controlPanel = UINib(nibName: "ControlPanel", bundle: nil).instantiateWithOwner(self, options: nil)[0] as! UIView
            controlPanel.frame = CGRectMake(0, 0, viewWidth, viewHeight)
            view.layer.shadowOpacity = 0.8
            dragPill.layer.cornerRadius = 5
            
            //Add animation to statusLabel
            let timer = NSTimer.scheduledTimerWithTimeInterval(0.4, target: self, selector: #selector(applySearchingEffect), userInfo: nil, repeats: true)
            timer.fire()
            
            //Adding Blur Effect
            let blurEffect = UIBlurEffect(style: .Dark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = CGRectMake(0, 0, viewWidth, viewHeight + 66 + statusBarHeight)
            view.insertSubview(blurView, atIndex: 0)
            
            //add controlPanel ontop
            view.addSubview(controlPanel)
            
            //add friends table view delegate and data source to self
            friendsTable.delegate = self
            friendsTable.dataSource = self
            friendsTable.registerNib(UINib(nibName: "ControlPanelCell", bundle: nil), forCellReuseIdentifier: "ControlPanelCell")
        
            if self.tableViewControl.selectedSegmentIndex == 0 {
                friendsPromptMessage.text = "Unable to find any sessions at the moment. Please check back later."
            } else {
                friendsPromptMessage.text = "Unable to find any friends at the moment. Please check back later."
            }
            
            friendsTable.hidden = true
            friendsPrompt.hidden = false
            
            self.setTableViewControl()
            self.updateMap(nil)
        }
        
        func setTableViewControl() {
            let normalFont = UIFont(name: "Hero", size: 16.0)
            let fontShadow = NSShadow()
            fontShadow.shadowColor = UIColor.blackColor()
            fontShadow.shadowOffset = CGSize(width: 1, height: 1)

            let normalTextAttributes: [NSObject : AnyObject] = [
                NSForegroundColorAttributeName: Colors.colorWithHexString(Colors.babyBlue()),
                NSFontAttributeName: normalFont!,
                NSShadowAttributeName: fontShadow
            ]
            
            let selectedTextAttributes: [NSObject : AnyObject] = [
                NSForegroundColorAttributeName: UIColor.whiteColor(),
                NSFontAttributeName: normalFont!,
                NSShadowAttributeName: fontShadow
            ]
            
            tableViewControl.setTitleTextAttributes(normalTextAttributes, forState: .Normal)
            tableViewControl.setTitleTextAttributes(selectedTextAttributes, forState: .Selected)
            tableViewControl.tintColor = Colors.colorWithHexString(Colors.babyBlue())
        }
        
        override func didReceiveMemoryWarning() {
            super.didReceiveMemoryWarning()
        }
        
        func applySearchingEffect() {
            if let str = statusLabel.text {
                let range = NSMakeRange(str.characters.count - numberOfDots, numberOfDots)
                let string = NSMutableAttributedString(string: str)
                string.addAttribute(NSForegroundColorAttributeName, value: UIColor.clearColor(), range: range)
                
                statusLabel.attributedText = string
                numberOfDots-=1
                if numberOfDots < 0 {
                    numberOfDots = 3
                }
            }
        }
        
        func clearLoggedinFlagInUserDefaults() {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.removeObjectForKey("userLoggedIn")
            defaults.synchronize()
        }
        
        func clearCoreData(entityName: String) {
            //1
            let appDelegate =
                UIApplication.sharedApplication().delegate as! AppDelegate
            
            let managedContext = appDelegate.managedObjectContext
            
            //2
            let fetchRequest = NSFetchRequest(entityName: entityName)
            
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
        
        //BUTTON ACTIONS
        @IBAction func morePressed(sender: AnyObject) {
            
            let viewProfile = FloatingAction(title: "View Profile") { action in
                print ("View Profile")
            }
            
            let notifications = FloatingAction(title: "Notifications ( \(UIApplication.sharedApplication().applicationIconBadgeNumber) )") { action in
                self.delegate?.showNotificationsViewController()
            }
            
            let signOut = FloatingAction(title: "Sign Out") { action in
                self.sendSignOut()
                self.signOut()
                UIApplication.sharedApplication().applicationIconBadgeNumber = 0
            }
            
            let cancel = FloatingAction(title: "Cancel") { action in }
            cancel.customTextColor = UIColor.whiteColor()
            
            let actionGroup = FloatingActionGroup(action: viewProfile, notifications, signOut, cancel)
            let actionSheet = FloatingActionSheetController(actionGroup: actionGroup, animationStyle: .SlideUp)

            // Color of action sheet
            actionSheet.itemTintColor = .blackColor()
            // Color of title texts
            actionSheet.textColor = Colors.colorWithHexString(Colors.babyBlue())
            // Font of title texts
            actionSheet.font = UIFont(name: "Hero", size: 18.0)!
            // background dimming color
            actionSheet.dimmingColor = UIColor.grayColor().colorWithAlphaComponent(0.8)
            
            actionSheet.present(self)
        }
        
        func signOut() {
            clearLoggedinFlagInUserDefaults()
            clearCoreData("Friend")
            clearCoreData("Notification")
            clearCoreData("Session")
            delegate?.SignedOut()
        }
        
        func sendSignOut() {
            // 1. Create HTTP request and set request header
            let httpRequest = httpHelper.buildRequest("signout", method: "GET",
                                                      authType: HTTPRequestAuthType.HTTPTokenAuth)
            
            // 2. Send the request
            httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
                if error != nil {
                    let errorMessage = self.httpHelper.getErrorMessage(error)
                    self.displayErrorAlert(errorMessage as String)
                    return
                }
            })
        }
        
        @IBAction func addFriendPressed(sender: UIButton) {
            //self.view.hidden = true
            self.delegate?.showAddFriendViewController()
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
        
        func refreshFriendsTV() {
            //get Context
            let managedContext = appDelegate.managedObjectContext
            
            let fetchRequest = NSFetchRequest(entityName: "Friend")
            
            do {
                let results =
                    try managedContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
                friends = []
                friends = results
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
            
            if friendsTable != nil {
                friendsTable.reloadData()
            }
        }
        
        func removeFriend(firstName: String, username: String) {
            //Create are you sure alert
            let areYouSureAlert = UIAlertController(title: "Remove \(firstName)", message: "Are you sure you would like to remove this friend?", preferredStyle: .Alert)
            let removeFriend = UIAlertAction(title: "Remove", style: .Destructive) { action in
                self.delegate?.removeFriend(username, selectedCell: nil)
            }
            let cancelRemove = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            areYouSureAlert.addAction(removeFriend)
            areYouSureAlert.addAction(cancelRemove)
            
            //Show are you sure alert
            self.presentViewController(areYouSureAlert, animated: true, completion: nil)
        }
        
        func updateMap(sessionData: [String: AnyObject]?) {
            if (sessionData != nil) {
                self.cancelButton.imageView!.image = UIImage(named:"Delete")
                if let friendId = sessionData!["friend_id"] as? Int {
                    if let userIndex = friends.indexOf({ $0.valueForKey("id") as! Int == friendId }) {
                        let firstName = friends[userIndex].valueForKey("first_name") as! String
                        let lastName = friends[userIndex].valueForKey("last_name") as! String
                        nameLabel.text = "\(firstName) \(lastName[lastName.startIndex.advancedBy(0)])."
                        
                        if let status = sessionData!["status"] as? String {
                            switch(status.lowercaseString) {
                            case "requested":
                                statusLabel.text = "Currently Requesting Location..."
                                break
                            default:
                                statusLabel.text = "Currently Tracking Location..."
                                break
                            }
                        }
                    }
                }
                self.toggleCancelButton()
                self.currentMap = mapState.trackingMap
            } else {
                //unsubscribed - switch to my current location
                if let firstname = defaults.objectForKey("first_name") as? String,
                    lastname = defaults.objectForKey("last_name") as? String {
                    nameLabel.text = "\(firstname) \(lastname[lastname.startIndex.advancedBy(0)])."
                } else {
                    nameLabel.text = "SKIY HOME"
                }
                let activeSessions = self.delegate?.getSessionsCount("active")
                if activeSessions == 0 {
                    statusLabel.text = "No Active Sessions..."
                } else {
                    statusLabel.text = "Currently tracking \(activeSessions!) people..."
                }
                self.toggleCancelButton()
            }
        }
        
        func toggleCancelButton() {
            if self.cancelButton.hidden == true {
                self.cancelButton.hidden = false
                self.removeMarkersButton.hidden = true
            } else {
                self.cancelButton.hidden = true
                self.removeMarkersButton.hidden = false
            }
        }
        
        @IBAction func cancelPressed(sender: UIButton) {
            self.delegate?.unsubscribe(nil, channelType: "RequestChannel")
            self.updateMap(nil)
            self.currentMap = mapState.homeMap
        }
        
        @IBAction func removeMarkersPressed(sender: UIButton) {
            
        }
        
        @IBAction func tableViewChanged(sender: UISegmentedControl) {
            self.friendsTable.reloadData()
        }
        
    }
    

    
    extension ControlPanelViewController: UITableViewDataSource {
        func numberOfSectionsInTableView(tableView: UITableView) -> Int {
            if tableViewControl.selectedSegmentIndex == 0 {
                return 4
            }
            return 3
        }
        
        func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            
            if tableViewControl.selectedSegmentIndex == 0 {
                let activeSessionsCount = (self.delegate?.getSessionsCount("active"))!
                let requestedSessionsCount = (self.delegate?.getSessionsCount("requested"))!
                let pendingSessionsCount = (self.delegate?.getSessionsCount("pending"))!
                let cancelledSessionsCount = (self.delegate?.getSessionsCount("cancelled"))!
                
                if activeSessionsCount > 0 || pendingSessionsCount > 0 || cancelledSessionsCount > 0 || requestedSessionsCount > 0 {
                    friendsTable.hidden = false
                    friendsPrompt.hidden = true
                } else {
                    friendsPromptMessage.text = "Unable to find any sessions at the moment. Please check back later."
                    friendsTable.hidden = true
                    friendsPrompt.hidden = false
                }
                
                switch (section) {
                case 0:
                    return activeSessionsCount
                case 1:
                    return pendingSessionsCount
                case 2:
                    return requestedSessionsCount
                default:
                    return cancelledSessionsCount
                }
            } else {
                if friends.count > 0 {
                    friendsTable.hidden = false
                    friendsPrompt.hidden = true
                } else {
                    friendsPromptMessage.text = "Unable to find any sessions at the moment. Please check back later."
                    friendsTable.hidden = true
                    friendsPrompt.hidden = false
                }
                
                switch (section) {
                case 0:
                    let pendingArray = friends.filter({ $0.valueForKey("status") as! String == "pending" })
                    return pendingArray.count
                case 1:
                    let requestedArray = friends.filter({ $0.valueForKey("status") as! String == "requested" })
                    return requestedArray.count
                default:
                    let friendsArray = friends.filter({ $0.valueForKey("status") as! String == "friends" })
                    return friendsArray.count
                }
            }
        }
        
        func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            if tableView.dataSource!.tableView(tableView, numberOfRowsInSection: section) == 0 { return "" }
            
            if self.tableViewControl.selectedSegmentIndex == 0 {
                switch(section) {
                case 0:
                    return "Active Sessions"
                case 1:
                    return "Pending Sessions"
                case 2:
                    return "Requested Sessions"
                default:
                    return "Cancelled Sessions"
                }
            } else {
                switch (section) {
                case 0:
                    return "Pending Approval"
                case 1:
                    return "Requested Friends"
                default:
                    return "Friends"
                }
            }
        }
        
        func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
            let header: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
            header.contentView.backgroundColor = UIColor.grayColor()
            header.textLabel!.textColor = UIColor.whiteColor()
            header.textLabel!.textAlignment = NSTextAlignment.Center
            header.textLabel!.font = UIFont(name: "Hero", size: 20.0)
            header.textLabel!.shadowColor = UIColor.blackColor()
            header.textLabel!.shadowOffset = CGSize(width: 1, height: 1)
        }
        
        func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let cell: ControlPanelCell = tableView.dequeueReusableCellWithIdentifier("ControlPanelCell", forIndexPath: indexPath) as! ControlPanelCell
            let topConstraint:NSLayoutConstraint = NSLayoutConstraint(item: cell.friendName, attribute: .CenterY, relatedBy: .Equal, toItem: cell, attribute: .CenterY, multiplier: 1.0, constant: 0.0)
            
            let activeArray = self.delegate?.getSessions("active")
            let requestedArray = self.delegate?.getSessions("requested")
            let pendingArray = self.delegate?.getSessions("pending")
            let cancelledArray = self.delegate?.getSessions("cancelled")
            var session: NSManagedObject
            
            //get session based on section and indexPath
            if self.tableViewControl.selectedSegmentIndex == 0 {
                switch(indexPath.section) {
                case 0:
                    tableView.rowHeight = 60
                    cell.friendStatus.backgroundColor = self.activeColor
                    cell.friendStatusLabel.text = "Currently Tracking Location"
                    session = activeArray![indexPath.row]
                    break
                case 1:
                    tableView.rowHeight = 60
                    cell.friendStatus.backgroundColor = self.pendingColor
                    cell.friendStatusLabel.text = "Expires: 3h 29m"
                    session = requestedArray![indexPath.row]
                    break
                case 2:
                    tableView.rowHeight = 60
                    cell.friendStatus.backgroundColor = self.requestColor
                    cell.friendStatusLabel.text = "Expires: 3h 29m"
                    session = pendingArray![indexPath.row]
                    break
                default:
                    tableView.rowHeight = 44
                    cell.friendStatus.removeFromSuperview()
                    cell.friendStatusLabel.removeFromSuperview()
                    cell.addConstraint(topConstraint)
                    session = cancelledArray![indexPath.row]
                    break
                }
                
                //get friend from session
                var friend: NSManagedObject?
                if let friend_id = session.valueForKey("friend_id") as? Int {
                    if let friendIndex = friends.indexOf({ $0.valueForKey("id") as! Int == friend_id }) {
                        friend = friends[friendIndex]
                    }
                }
                
                //fill in labels for cell
                if friend != nil {
                    cell.friendName.text = "\(friend!.valueForKey("first_name")!) \(friend!.valueForKey("last_name")!)"
                }
                cell.friendStatus.layer.cornerRadius = 3;
                cell.friendStatus.layer.masksToBounds = true;
                return cell
            } else {
                let pendingArray = friends.filter({ $0.valueForKey("status") as! String == "pending" })
                let requestedArray = friends.filter({ $0.valueForKey("status") as! String == "requested" })
                let friendsArray = friends.filter({ $0.valueForKey("status") as! String == "friends" })
                var person: NSManagedObject
                
                tableView.rowHeight = 44
                cell.friendStatus.removeFromSuperview()
                cell.friendStatusLabel.removeFromSuperview()
                cell.addConstraint(topConstraint)
                
                switch (indexPath.section) {
                case 0:
                    person = pendingArray[indexPath.row]
                    break
                case 1:
                    person = requestedArray[indexPath.row]
                    break
                default:
                    person = friendsArray[indexPath.row]
                    break
                }
                
                //Set cell attributes
                cell.friendName.text = "\(person.valueForKey("first_name")!) \(person.valueForKey("last_name")!)"
                return cell
            }
        }
    }
    
    
    // Mark: Table View Delegate
    
    extension ControlPanelViewController: UITableViewDelegate {
        func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
            var person: NSManagedObject
            var alert : UIAlertController
            var OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            let CancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            
            switch (indexPath.section) {
            case 0:
                break
            case 1:
                //get person
                let pendingArray = friends.filter({ $0.valueForKey("status") as! String == "pending" })
                person = pendingArray[indexPath.row]
                
                //Get attributes
                let firstName = person.valueForKey("first_name") as! String
                let lastName = person.valueForKey("last_name") as! String
                let username = person.valueForKey("username") as! String
                let status = person.valueForKey("status") as! String
                
                //show alert
                alert = UIAlertController(title: "\(firstName) \(lastName)", message: "\(firstName) has sent you a friend request. Would you like to accept this request?", preferredStyle: .Alert)
                OKAction = UIAlertAction(title: "Accept", style: .Default) { action in
                    self.delegate?.addFriend(username, status: status, selectedCell: nil)
                }
                alert.addAction(OKAction)
                alert.addAction(CancelAction)
                self.presentViewController(alert, animated: true, completion: nil)
                break
            case 2:
                //get person
                let requestedArray = friends.filter({ $0.valueForKey("status") as! String == "requested" })
                person = requestedArray[indexPath.row]
                
                //get attributes
                let firstName = person.valueForKey("first_name") as! String
                let lastName = person.valueForKey("last_name") as! String
                
                //show alert
                alert = UIAlertController(title: "\(firstName) \(lastName)", message: "Friend request has already been sent, please wait for \(firstName) to accept this request.", preferredStyle: .Alert)
                alert.addAction(OKAction)
                self.presentViewController(alert, animated: true, completion: nil)
                break
            default:
                //get person
                let friendsArray = friends.filter({ $0.valueForKey("status") as! String == "friends" })
                person = friendsArray[indexPath.row]
                
                //get attributes
                let firstName = person.valueForKey("first_name") as! String
                let username = person.valueForKey("username") as! String
                let id = person.valueForKey("id") as! Int
                
                
                let requestLocation = FloatingAction(title: "Request Location") { action in
                    //send to request to server
                    self.delegate?.sendRequest("REQUEST", friend_id: id)
                }
                
                let sendLocation = FloatingAction(title: "Send Location") { action in
                    print ("Send Location")
                }
                
                let profileAction = FloatingAction(title: "View Profile") { action in
                    print ("View Profile")
                }
                
                let removeFriend = FloatingAction(title: "Remove Friend") { action in
                    self.removeFriend(firstName, username: username)
                }
                
                let cancel = FloatingAction(title: "Cancel") { action in }
                cancel.customTextColor = UIColor.whiteColor()
                
                let actionGroup = FloatingActionGroup(action: requestLocation, sendLocation, profileAction, removeFriend, cancel)
                let actionSheet = FloatingActionSheetController(actionGroup: actionGroup, animationStyle: .SlideUp)
                
                // Color of action sheet
                actionSheet.itemTintColor = .blackColor()
                // Color of title texts
                actionSheet.textColor = Colors.colorWithHexString(Colors.babyBlue())
                // Font of title texts
                actionSheet.font = UIFont(name: "Hero", size: 18.0)!
                // background dimming color
                actionSheet.dimmingColor = UIColor.grayColor().colorWithAlphaComponent(0.8)
                
                actionSheet.present(self)
                break
            }
        }
    }

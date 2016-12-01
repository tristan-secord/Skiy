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
        func addFriend(_ username: String, status: String, selectedCell: FindFriendsCell?)
        func removeFriend(_ username: String, selectedCell: FindFriendsCell?)
        func friendRemoved(_ username: String, selectedCell: FindFriendsCell?)
        func acceptLocationRequest(_ responseDict: [String: AnyObject])
        func acceptShareRequest(_ sendDict: [String: AnyObject], requestDict: [String: AnyObject])
        func sendRequest(_ type: String, friend_id: Int)
        func updateFriendsTableView()
        func unsubscribe(_ session_id: Int?, channelType: String)
        func getSessionsCount(_ type: String) -> Int
        func getSessions(_ type: String) -> Array<NSManagedObject>
        func removeReceiver(session: NSManagedObject)
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
        let defaults = UserDefaults.standard
        let appDelegate =
            UIApplication.shared.delegate as! AppDelegate
        let statusBarHeight =
            UIApplication.shared.statusBarFrame.size.height
        
        var requestColor: UIColor = Colors.colorWithHexString("#4CD964") // green
        var pendingColor: UIColor = Colors.colorWithHexString("#8E8E93") // gray
        var sendColor: UIColor = Colors.colorWithHexString("#5AC8FB") // blue
        var stopColor: UIColor = Colors.colorWithHexString("#EF4836") //red
        
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
            let controlPanel = UINib(nibName: "ControlPanel", bundle: nil).instantiate(withOwner: self, options: nil)[0] as! UIView
            controlPanel.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
            view.layer.shadowOpacity = 0.8
            dragPill.layer.cornerRadius = 5
            
            //Add animation to statusLabel
            let timer = Timer.scheduledTimer(timeInterval: 0.4, target: self, selector: #selector(applySearchingEffect), userInfo: nil, repeats: true)
            timer.fire()
            
            //Adding Blur Effect
            let blurEffect = UIBlurEffect(style: .dark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight + 66 + statusBarHeight)
            view.insertSubview(blurView, at: 0)
            
            //add controlPanel ontop
            view.addSubview(controlPanel)
            
            //add friends table view delegate and data source to self
            friendsTable.delegate = self
            friendsTable.dataSource = self
            friendsTable.register(UINib(nibName: "ControlPanelCell", bundle: nil), forCellReuseIdentifier: "ControlPanelCell")
            friendsTable.register(UINib(nibName: "ControlPanelFriendCell", bundle: nil), forCellReuseIdentifier: "ControlPanelFriendCell")
        
            if self.tableViewControl.selectedSegmentIndex == 0 {
                friendsPromptMessage.text = "Unable to find any sessions at the moment. Please check back later."
            } else {
                friendsPromptMessage.text = "Unable to find any friends at the moment. Please check back later."
            }
            
            friendsTable.isHidden = true
            friendsPrompt.isHidden = false
            
            self.setTableViewControl()
            self.updateMap(nil)
        }
        
        func setTableViewControl() {
            let normalFont = UIFont(name: "Hero", size: 16.0)
            let fontShadow = NSShadow()
            fontShadow.shadowColor = UIColor.black
            fontShadow.shadowOffset = CGSize(width: 1, height: 1)

            let normalTextAttributes: [AnyHashable: Any] = [
                NSForegroundColorAttributeName: Colors.colorWithHexString(Colors.babyBlue()),
                NSFontAttributeName: normalFont!,
                NSShadowAttributeName: fontShadow
            ]
            
            let selectedTextAttributes: [AnyHashable: Any] = [
                NSForegroundColorAttributeName: UIColor.white,
                NSFontAttributeName: normalFont!,
                NSShadowAttributeName: fontShadow
            ]
            
            tableViewControl.setTitleTextAttributes(normalTextAttributes, for: UIControlState())
            tableViewControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
            tableViewControl.tintColor = Colors.colorWithHexString(Colors.babyBlue())
        }
        
        override func didReceiveMemoryWarning() {
            super.didReceiveMemoryWarning()
        }
        
        func applySearchingEffect() {
            if let str = statusLabel.text {
                let range = NSMakeRange(str.characters.count - numberOfDots, numberOfDots)
                let string = NSMutableAttributedString(string: str)
                string.addAttribute(NSForegroundColorAttributeName, value: UIColor.clear, range: range)
                
                statusLabel.attributedText = string
                numberOfDots-=1
                if numberOfDots < 0 {
                    numberOfDots = 3
                }
            }
        }
        
        func clearLoggedinFlagInUserDefaults() {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "userLoggedIn")
            defaults.synchronize()
        }
        
        func clearCoreData(_ entityName: String) {
            //1
            let appDelegate =
                UIApplication.shared.delegate as! AppDelegate
            
            let managedContext = appDelegate.managedObjectContext
            
            //2
            let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)

            
            //3
            do {
                let results =
                    try managedContext.fetch(fetchRequest)
                
                if results.count > 0 {
                    for result in results {
                        managedContext.delete(result as! NSManagedObject)
                    }
                    try managedContext.save()
                }
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        
        //BUTTON ACTIONS
        @IBAction func morePressed(_ sender: AnyObject) {
            
            let viewProfile = FloatingAction(title: "View Profile") { action in
                print ("View Profile")
            }
            
            let notifications = FloatingAction(title: "Notifications ( \(UIApplication.shared.applicationIconBadgeNumber) )") { action in
                self.delegate?.showNotificationsViewController()
            }
            
            let signOut = FloatingAction(title: "Sign Out") { action in
                self.sendSignOut()
                self.signOut()
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            
            let cancel = FloatingAction(title: "Cancel") { action in }
            cancel.textColor = UIColor.white
            
            let actionGroup = FloatingActionGroup(action: viewProfile, notifications, signOut, cancel)
            let actionSheet = FloatingActionSheetController(actionGroup: actionGroup, animationStyle: .slideUp)

            // Color of action sheet
            actionSheet.itemTintColor = UIColor.black
            // Color of title texts
            actionSheet.textColor = Colors.colorWithHexString(Colors.babyBlue())
            // Font of title texts
            actionSheet.font = UIFont(name: "Hero", size: 18.0)!
            // background dimming color
            actionSheet.dimmingColor = UIColor.gray.withAlphaComponent(0.8)
            
            actionSheet.present(in: self)
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
                                                      authType: HTTPRequestAuthType.httpTokenAuth)
            
            // 2. Send the request
            httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
                if error != nil {
//                    let errorMessage = self.httpHelper.getErrorMessage(error)
                    self.displayErrorAlert((error?.localizedDescription)! as String)
                    return
                }
            })
        }
        
        @IBAction func addFriendPressed(_ sender: UIButton) {
            //self.view.hidden = true
            self.delegate?.showAddFriendViewController()
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
        
        func refreshFriendsTV() {
            //get Context
            let managedContext = appDelegate.managedObjectContext
            
            let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Friend")
            
            do {
                let results =
                    try managedContext.fetch(fetchRequest) as! [NSManagedObject]
                friends = []
                friends = results
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
            
            if friendsTable != nil {
                friendsTable.reloadData()
            }
        }
        
        func removeFriend(_ firstName: String, username: String) {
            //Create are you sure alert
            let areYouSureAlert = UIAlertController(title: "Remove \(firstName)", message: "Are you sure you would like to remove this friend?", preferredStyle: .alert)
            let removeFriend = UIAlertAction(title: "Remove", style: .destructive) { action in
                self.delegate?.removeFriend(username, selectedCell: nil)
            }
            let cancelRemove = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            areYouSureAlert.addAction(removeFriend)
            areYouSureAlert.addAction(cancelRemove)
            
            //Show are you sure alert
            self.present(areYouSureAlert, animated: true, completion: nil)
        }
        
        func updateMap(_ sessionData: [String: AnyObject]?) {
            if (sessionData != nil) {
                self.cancelButton.imageView!.image = UIImage(named:"Delete")
                if let friendId = sessionData!["friend_id"] as? Int {
                    if let userIndex = friends.index(where: { $0.value(forKey: "id") as! Int == friendId }) {
                        let firstName = friends[userIndex].value(forKey: "first_name") as! String
                        let lastName = friends[userIndex].value(forKey: "last_name") as! String
                        nameLabel.text = "\(firstName) \(lastName[lastName.characters.index(lastName.startIndex, offsetBy: 0)])."
                        
                        if let status = sessionData!["status"] as? String {
                            switch(status.lowercased()) {
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
                self.toggleCancelButton(cancel: true)
                self.currentMap = mapState.trackingMap
            } else {
                //unsubscribed - switch to my current location
                if let firstname = defaults.object(forKey: "first_name") as? String,
                    let lastname = defaults.object(forKey: "last_name") as? String {
                    nameLabel.text = "\(firstname) \(lastname[lastname.characters.index(lastname.startIndex, offsetBy: 0)])."
                } else {
                    nameLabel.text = "SKIY HOME"
                }
                let activeSessions = self.delegate?.getSessionsCount("active")
                if activeSessions == 0 {
                    statusLabel.text = "No Active Sessions..."
                } else {
                    statusLabel.text = "Currently tracking \(activeSessions!) people..."
                }
                self.toggleCancelButton(cancel: false)
                self.currentMap = mapState.homeMap
            }
        }
        
        func toggleCancelButton(cancel: Bool) {
            if cancel {
                self.cancelButton.isHidden = false
                self.removeMarkersButton.isHidden = true
            } else {
                self.cancelButton.isHidden = true
                self.removeMarkersButton.isHidden = false
            }
        }
        
        @IBAction func cancelPressed(_ sender: UIButton) {
            self.delegate?.unsubscribe(nil, channelType: "RequestChannel")
            self.updateMap(nil)
            self.currentMap = mapState.homeMap
            refreshFriendsTV()
        }
        
        @IBAction func removeMarkersPressed(_ sender: UIButton) {
            
        }
        
        @IBAction func tableViewChanged(_ sender: UISegmentedControl) {
            self.friendsTable.reloadData()
            
            //print out CoreData -- DELETE!!!!
            let managedContext = appDelegate.managedObjectContext
            
            if tableViewControl.selectedSegmentIndex == 0 {
                let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Session")
                
                do {
                    let results =
                        try managedContext.fetch(fetchRequest) as! [NSManagedObject]
                    for i in 0..<results.count {
                        print(results[i])
                    }
                } catch let error as NSError {
                    print("Could not fetch \(error), \(error.userInfo)")
                }
            } else {
                let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Friend")
                
                do {
                    let results =
                        try managedContext.fetch(fetchRequest) as! [NSManagedObject]
                    for i in 0..<results.count {
                        print(results[i])
                    }
                } catch let error as NSError {
                    print("Could not fetch \(error), \(error.userInfo)")
                }

            }
        }
    }
    

    
    extension ControlPanelViewController: UITableViewDataSource {
        func numberOfSections(in tableView: UITableView) -> Int {
            if tableViewControl.selectedSegmentIndex == 0 {
                return 4
            }
            return 3
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            
            if tableViewControl.selectedSegmentIndex == 0 {
                let activeSessionsCount = (self.delegate?.getSessionsCount("active"))!
                let requestedSessionsCount = (self.delegate?.getSessionsCount("requested"))!
                let pendingSessionsCount = (self.delegate?.getSessionsCount("pending"))!
                let cancelledSessionsCount = (self.delegate?.getSessionsCount("cancelled"))!
                
                if activeSessionsCount > 0 || pendingSessionsCount > 0 || cancelledSessionsCount > 0 || requestedSessionsCount > 0 {
                    friendsTable.isHidden = false
                    friendsPrompt.isHidden = true
                } else {
                    friendsPromptMessage.text = "Unable to find any sessions at the moment. Please check back later."
                    friendsTable.isHidden = true
                    friendsPrompt.isHidden = false
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
                    friendsTable.isHidden = false
                    friendsPrompt.isHidden = true
                } else {
                    friendsPromptMessage.text = "Unable to find any friends at the moment. Please check back later."
                    friendsTable.isHidden = true
                    friendsPrompt.isHidden = false
                }
                
                switch (section) {
                case 0:
                    let pendingArray = friends.filter({ $0.value(forKey: "status") as! String == "pending" })
                    return pendingArray.count
                case 1:
                    let requestedArray = friends.filter({ $0.value(forKey: "status") as! String == "requested" })
                    return requestedArray.count
                default:
                    let friendsArray = friends.filter({ $0.value(forKey: "status") as! String == "friends" })
                    return friendsArray.count
                }
            }
        }
        
        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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
        
        func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
            let header: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
            header.contentView.backgroundColor = UIColor.gray
            header.textLabel!.textColor = UIColor.white
            header.textLabel!.textAlignment = NSTextAlignment.center
            header.textLabel!.font = UIFont(name: "Hero", size: 20.0)
            header.textLabel!.shadowColor = UIColor.black
            header.textLabel!.shadowOffset = CGSize(width: 1, height: 1)
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
           
            
            let activeArray = self.delegate?.getSessions("active")
            let requestedArray = self.delegate?.getSessions("requested")
            let pendingArray = self.delegate?.getSessions("pending")
            let cancelledArray = self.delegate?.getSessions("cancelled")
            var session: NSManagedObject
            
            //get session based on section and indexPath
            if self.tableViewControl.selectedSegmentIndex == 0 {
                let cell: ControlPanelCell = tableView.dequeueReusableCell(withIdentifier: "ControlPanelCell", for: indexPath) as! ControlPanelCell
                let centerName: NSLayoutConstraint = NSLayoutConstraint(item: cell.friendName, attribute: .centerY, relatedBy: .equal, toItem: cell, attribute: .centerY, multiplier: 1.0, constant: 0.0)
                switch((indexPath as NSIndexPath).section) {
                case 0:
                    cell.addConstraint(centerName)
                    cell.expiryLabel.isHidden = true
                    tableView.rowHeight = 60
                    session = activeArray![(indexPath as NSIndexPath).row]
                    switch(session.value(forKey: "type") as! String) {
                    case "REQUEST":
                        cell.sessionStatus.text = "Receiving Location"
                        cell.sessionStatus.textColor = self.requestColor
                        break
                    default:
                        cell.sessionStatus.text = "Sending Location"
                        cell.sessionStatus.textColor = self.sendColor
                        break
                    }
                    break
                case 1:
                    cell.removeConstraint(centerName)
                    cell.expiryLabel.isHidden = false
                    tableView.rowHeight = 60
                    cell.expiryLabel.text = "Expires: 3h 29m"
                    session = pendingArray![(indexPath as NSIndexPath).row]
                    switch(session.value(forKey: "type") as! String) {
                    case "REQUEST":
                        cell.sessionStatus.text = "Receiving Location"
                        cell.sessionStatus.textColor = self.pendingColor
                        break
                    default:
                        cell.sessionStatus.text = "Sending Location"
                        cell.expiryLabel.text = "Currently Sending Location"
                        cell.sessionStatus.textColor = self.pendingColor
                        break
                    }
                    break
                case 2:
                    cell.removeConstraint(centerName)
                    cell.expiryLabel.isHidden = false
                    tableView.rowHeight = 60
                    cell.expiryLabel.text = "Expires: 3h 29m"
                    session = requestedArray![(indexPath as NSIndexPath).row]
                    switch(session.value(forKey: "type") as! String) {
                    case "REQUEST":
                        cell.sessionStatus.text = "Receiving Location"
                        cell.sessionStatus.textColor = self.pendingColor
                        break
                    default:
                        cell.sessionStatus.text = "Sending Location"
                        cell.sessionStatus.textColor = self.pendingColor
                        break
                    }
                    break
                default:
                    cell.removeConstraint(centerName)
                    cell.expiryLabel.isHidden = false
                    tableView.rowHeight = 60
                    cell.sessionStatus.isHidden = true
                    cell.statusSeperator.isHidden = true
                    session = cancelledArray![(indexPath as NSIndexPath).row]
                    switch(session.value(forKey: "type") as! String) {
                    case "REQUEST":
                        cell.expiryLabel.text = "Stopped Tracking Location"
                        break
                    default:
                        cell.expiryLabel.text = "Stopped Sending Location"
                        break
                    }
                    break
                }
                
                //get friend from session
                var friend: NSManagedObject?
                
                
                if let friend_id = session.value(forKey: "friend_id") as? Int {
                    if let friendIndex = friends.index(where: { $0.value(forKey: "id") as! Int == friend_id }) {
                        friend = friends[friendIndex]
                    }
                }
                
                //fill in labels for cell
                if friend != nil {
                    cell.friendName.text = "\(friend!.value(forKey: "first_name")!) \(friend!.value(forKey: "last_name")!)"
                }
                return cell
            } else {
                let cell: ControlPanelFriendCell = tableView.dequeueReusableCell(withIdentifier: "ControlPanelFriendCell", for: indexPath) as! ControlPanelFriendCell
                
                let pendingArray = friends.filter({ $0.value(forKey: "status") as! String == "pending" })
                let requestedArray = friends.filter({ $0.value(forKey: "status") as! String == "requested" })
                let friendsArray = friends.filter({ $0.value(forKey: "status") as! String == "friends" })
                var person: NSManagedObject
                
                tableView.rowHeight = 44
                
                switch ((indexPath as NSIndexPath).section) {
                case 0:
                    person = pendingArray[(indexPath as NSIndexPath).row]
                    break
                case 1:
                    person = requestedArray[(indexPath as NSIndexPath).row]
                    break
                default:
                    person = friendsArray[(indexPath as NSIndexPath).row]
                    break
                }
                
                //Set cell attributes
                cell.friendName.text = "\(person.value(forKey: "first_name")!) \(person.value(forKey: "last_name")!)"
                return cell
            }
        }
    }
    
    
    // Mark: Table View Delegate
    
    extension ControlPanelViewController: UITableViewDelegate {
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            var person: NSManagedObject
            var alert : UIAlertController
            var OKAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            let CancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            if self.tableViewControl.selectedSegmentIndex == 0 {
                switch ((indexPath as NSIndexPath).section) {
                case 0:
                    //get session
                    let activeSessions = self.delegate?.getSessions("active")
                    let session = activeSessions![(indexPath as NSIndexPath).row]
                    
                    let cancelSession = FloatingAction(title: "Cancel Session") { action in
                        if session.value(forKey: "type") as! String == "REQUEST" {
                            self.delegate?.unsubscribe(session.value(forKey: "id") as? Int, channelType: "RequestChannel")
                        } else {
                            self.delegate?.removeReceiver(session: session)
                        }
                        self.updateMap(nil)
                        self.currentMap = mapState.homeMap
                        self.refreshFriendsTV()
                    }
                    
                    let showSession = FloatingAction(title: "Show Session") { action in
                        if session.value(forKey: "type") as! String == "REQUEST" {
                            //SHOW SESSION
                        }
                    }
                    
                    let cancel = FloatingAction(title: "Cancel") { action in }
                    cancel.textColor = UIColor.red
                    
                    let actionGroup = FloatingActionGroup(action: showSession, cancelSession, cancel)
                    let actionSheet = CustomFloatingActionSheetController(actionGroup: actionGroup, animationStyle: .slideUp).actionSheet
                    
                    actionSheet.present(in: self)
                    break
                case 1:
                    break
                case 2:
                    break
                default:
                    break
                }
            } else {
                switch ((indexPath as NSIndexPath).section) {
                case 0:
                    //get person
                    let pendingArray = friends.filter({ $0.value(forKey: "status") as! String == "pending" })
                    person = pendingArray[(indexPath as NSIndexPath).row]
                    
                    //Get attributes
                    let firstName = person.value(forKey: "first_name") as! String
                    let lastName = person.value(forKey: "last_name") as! String
                    let username = person.value(forKey: "username") as! String
                    let status = person.value(forKey: "status") as! String
                    
                    //show alert
                    alert = UIAlertController(title: "\(firstName) \(lastName)", message: "\(firstName) has sent you a friend request. Would you like to accept this request?", preferredStyle: .alert)
                    OKAction = UIAlertAction(title: "Accept", style: .default) { action in
                        self.delegate?.addFriend(username, status: status, selectedCell: nil)
                    }
                    alert.addAction(OKAction)
                    alert.addAction(CancelAction)
                    self.present(alert, animated: true, completion: nil)
                    break
                case 1:
                    //get person
                    let requestedArray = friends.filter({ $0.value(forKey: "status") as! String == "requested" })
                    person = requestedArray[(indexPath as NSIndexPath).row]
                    
                    //get attributes
                    let firstName = person.value(forKey: "first_name") as! String
                    let lastName = person.value(forKey: "last_name") as! String
                    
                    //show alert
                    alert = UIAlertController(title: "\(firstName) \(lastName)", message: "Friend request has already been sent, please wait for \(firstName) to accept this request.", preferredStyle: .alert)
                    alert.addAction(OKAction)
                    self.present(alert, animated: true, completion: nil)
                    break
                default:
                    //get person
                    let friendsArray = friends.filter({ $0.value(forKey: "status") as! String == "friends" })
                    person = friendsArray[(indexPath as NSIndexPath).row]
                    
                    //get attributes
                    let firstName = person.value(forKey: "first_name") as! String
                    let username = person.value(forKey: "username") as! String
                    let id = person.value(forKey: "id") as! Int
                    
                    
                    let requestLocation = FloatingAction(title: "Request Location") { action in
                        //send to request to server
                        self.delegate?.sendRequest("REQUEST", friend_id: id)
                    }
                    
                    let shareLocation = FloatingAction(title: "Share Location") { action in
                        //share locations
                        self.delegate?.sendRequest("SHARE", friend_id: id)
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
                    cancel.textColor = UIColor.white
                    
                    let actionGroup = FloatingActionGroup(action: requestLocation, shareLocation, sendLocation, profileAction, removeFriend, cancel)
                    let actionSheet = CustomFloatingActionSheetController(actionGroup: actionGroup, animationStyle: .slideUp).actionSheet
                    
                    actionSheet.present(in: self)
                    break
                }
            }
        }
    }

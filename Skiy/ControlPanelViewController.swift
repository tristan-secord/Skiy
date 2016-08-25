    //
    //  ControlPanelViewController.swift
    //  Skiy
    //
    //  Created by Tristan Secord on 2016-05-21.
    //  Copyright © 2016 Tristan Secord. All rights reserved.
    //
    
    import UIKit
    import CoreData
    
    protocol ControlPanelViewControllerDelegate {
        func SignedOut()
        func showAddFriendViewController()
        func addFriend(username: String, status: String, selectedCell: FindFriendsCell?)
        func removeFriend(username: String, selectedCell: FindFriendsCell?)
    }
    
    class ControlPanelViewController: UIViewController {
        
        @IBOutlet weak var friendsTable: UITableView!
        @IBOutlet weak var nameLabel: UILabel!
        @IBOutlet weak var statusLabel: UILabel!
        @IBOutlet weak var dragPill: UIView!
        var delegate: ControlPanelViewControllerDelegate?
        var numberOfDots = 3
        var friends = [NSManagedObject]()
        typealias Payload = [String: AnyObject]
        var httpHelper = HTTPHelper()
        let defaults = NSUserDefaults.standardUserDefaults()
        let appDelegate =
            UIApplication.sharedApplication().delegate as! AppDelegate
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            let viewWidth = view.frame.size.width
            let viewHeight = view.frame.size.height
            
            //instantiate control panel
            let controlPanel = UINib(nibName: "ControlPanel", bundle: nil).instantiateWithOwner(self, options: nil)[0] as! UIView
            controlPanel.frame = CGRectMake(0, 0, viewWidth, viewHeight + 66)
            view.layer.shadowOpacity = 0.8
            dragPill.layer.shadowOpacity = 0.8
            dragPill.layer.cornerRadius = 5
            
            
            //Add animation to statusLabel
            let timer = NSTimer.scheduledTimerWithTimeInterval(0.4, target: self, selector: #selector(applySearchingEffect), userInfo: nil, repeats: true)
            timer.fire()
            
            
            //Adding Blur Effect
            let blurEffect = UIBlurEffect(style: .Dark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = CGRectMake(0, 0, viewWidth, viewHeight + 66)
            view.insertSubview(blurView, atIndex: 0)
            
            //add controlPanel ontop
            view.addSubview(controlPanel)
            
            //add vibrancy effect to controlpanel
            let vibrancyEffect = UIVibrancyEffect(forBlurEffect: blurEffect)
            let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
            vibrancyView.frame = CGRectMake(0, 0, viewWidth, viewHeight + 66)
            vibrancyView.contentView.addSubview(controlPanel)
            blurView.contentView.addSubview(vibrancyView)
            
            //add friends table view delegate and data source to self
            friendsTable.delegate = self
            friendsTable.dataSource = self
            friendsTable.registerNib(UINib(nibName: "ControlPanelCell", bundle: nil), forCellReuseIdentifier: "ControlPanelCell")
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
        
        func clearCoreData() {
            //1
            let appDelegate =
                UIApplication.sharedApplication().delegate as! AppDelegate
            
            let managedContext = appDelegate.managedObjectContext
            
            //2
            let fetchRequest = NSFetchRequest(entityName: "Friend")
            
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
            clearLoggedinFlagInUserDefaults()
            clearCoreData()
            delegate?.SignedOut()
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
    }
    

    
    extension ControlPanelViewController: UITableViewDataSource {
        func numberOfSectionsInTableView(tableView: UITableView) -> Int {
            return 4
        }
        
        func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            switch (section) {
            case 0:
                return 0
            case 1:
                let pendingArray = friends.filter({ $0.valueForKey("status") as! String == "pending" })
                return pendingArray.count
            case 2:
                let requestedArray = friends.filter({ $0.valueForKey("status") as! String == "requested" })
                return requestedArray.count
            default:
                let friendsArray = friends.filter({ $0.valueForKey("status") as! String == "friends" })
                return friendsArray.count
            }
        }
        
        func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            if tableView.dataSource!.tableView(tableView, numberOfRowsInSection: section) == 0 { return "" }

            switch (section) {
            case 0:
                return "Active Sessions"
            case 1:
                return "Pending your Approval"
            case 2:
                return "Requested Friendships"
            default:
                return "Friends"
            }
        }
        
        func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
            let header: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
            header.contentView.backgroundColor = UIColor.grayColor()
            header.textLabel!.textColor = UIColor.whiteColor()
            header.textLabel!.textAlignment = NSTextAlignment.Center
        }
        
        func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let pendingArray = friends.filter({ $0.valueForKey("status") as! String == "pending" })
            let requestedArray = friends.filter({ $0.valueForKey("status") as! String == "requested" })
            let friendsArray = friends.filter({ $0.valueForKey("status") as! String == "friends" })
            let cell: ControlPanelCell = tableView.dequeueReusableCellWithIdentifier("ControlPanelCell", forIndexPath: indexPath) as! ControlPanelCell
            var person: NSManagedObject

            switch (indexPath.section) {
            //CASE 0 NEEDS TO BE CHANGED
            //Case 0 - Active Sessions
            //Case 1 - Pending
            //Case 2 - Requested
            //Case 3 - Friends
            case 0:
                tableView.rowHeight = 60
                cell.friendStatus.backgroundColor = UIColor.greenColor()
                cell.friendStatusLabel.text = "Currently Tracking Location"
                person = friends[indexPath.row]
                break
            case 1:
                tableView.rowHeight = 44
                cell.friendStatus.removeFromSuperview()
                cell.friendStatusLabel.removeFromSuperview()
                person = pendingArray[indexPath.row]
                break
            case 2:
                tableView.rowHeight = 44
                cell.friendStatus.removeFromSuperview()
                cell.friendStatusLabel.removeFromSuperview()
                person = requestedArray[indexPath.row]
                break
            default:
                tableView.rowHeight = 44
                cell.friendStatus.removeFromSuperview()
                cell.friendStatusLabel.removeFromSuperview()
                person = friendsArray[indexPath.row]
                break
            }
            
            //Set cell attributes
            cell.friendName.text = "\(person.valueForKey("first_name")!) \(person.valueForKey("last_name")!)"
            cell.friendStatus.layer.cornerRadius = 3;
            cell.friendStatus.layer.masksToBounds = true;
            return cell
        }
        
        func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
            // let the controller to know that able to edit tableView's row
            return true
        }
        
        func tableView(tableView: UITableView, commitEdittingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath)  {
            // if you want to apply with iOS 8 or earlier version you must add this function too. (just left in blank code)
        }
        
        func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]?  {
            // add the action button you want to show when swiping on tableView's cell , in this case add the delete button.
            let deleteAction = UITableViewRowAction(style: .Default, title: "Delete", handler: { (action , indexPath) -> Void in
                print("DELETE")
            })
            
            // You can set its properties like normal button
            deleteAction.backgroundColor = UIColor.redColor()
            
            return [deleteAction]
        }
        
        func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
            return .Delete
        }
    }
    
    
    // Mark: Table View Delegate
    
    extension ControlPanelViewController: UITableViewDelegate {
        func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
            var person: NSManagedObject
            var alert : UIAlertController
            var OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            var CancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            
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
                let lastName = person.valueForKey("last_name") as! String
                let username = person.valueForKey("username") as! String
                
                //show alert
                alert = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
                
                //Request location Action
                let requestLocation = UIAlertAction(title: "Request Location", style: .Default) { action in
                    print ("Request Location")
                }
                
                //Send Location Action
                let sendLocation = UIAlertAction(title: "Send Location", style: .Default) { action in
                    print ("Send Location")
                }
                
                //View Profile Action
                let profileAction = UIAlertAction(title: "View Profile", style: .Default) { action in
                    print("View Profile")
                }
                
                //Remove Friend Action
                let removeFriend = UIAlertAction(title: "Remove Friend", style: .Default) { action in
                    //Dismiss options action sheet
                    self.removeFriend(firstName, username: username)
                    alert.dismissViewControllerAnimated(true, completion: nil)
                }
                
                //Cancel
                CancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)

                
                alert.addAction(requestLocation)
                alert.addAction(sendLocation)
                alert.addAction(profileAction)
                alert.addAction(removeFriend)
                alert.addAction(CancelAction)
                
                self.presentViewController(alert, animated: true, completion: nil)
                break
                //
            }
            //START TRACKING!
        }
    }

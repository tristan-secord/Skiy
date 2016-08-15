    //
    //  ControlPanelViewController.swift
    //  Skiy
    //
    //  Created by Tristan Secord on 2016-05-21.
    //  Copyright © 2016 Tristan Secord. All rights reserved.
    //
    
    import UIKit
    
    protocol ControlPanelViewControllerDelegate {
        func SignedOut()
    }
    
    class ControlPanelViewController: UIViewController, AddFriendDelegate {
        
        @IBOutlet weak var friendsTable: UITableView!
        @IBOutlet weak var nameLabel: UILabel!
        @IBOutlet weak var statusLabel: UILabel!
        @IBOutlet weak var dragPill: UIView!
        var delegate: ControlPanelViewControllerDelegate?
        var numberOfDots = 3
        var addFriendViewController: AddFriendViewController?
        
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
        
        //BUTTON ACTIONS
        @IBAction func morePressed(sender: AnyObject) {
            clearLoggedinFlagInUserDefaults()
            delegate?.SignedOut()
        }
        
        @IBAction func addFriendPressed(sender: UIButton) {
            addFriendViewController = AddFriendViewController()
            if (addFriendViewController != nil) {
                self.dismissViewControllerAnimated(true, completion: nil)
                presentViewController(addFriendViewController!, animated: true, completion: nil)
                addFriendViewController!.delegate = self
            }
        }
        
        func hideAddFriend() {
            if (addFriendViewController != nil) {
                //self.dismissViewControllerAnimated(false, completion: nil)
                addFriendViewController?.dismissViewControllerAnimated(true, completion: nil)
            }
        }
    }
    
    extension ControlPanelViewController: UITableViewDataSource {
        func numberOfSectionsInTableView(tableView: UITableView) -> Int {
            return 3
        }
        
        func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            if (section == 0) {
                return 3
            } else if (section == 1) {
                return 3
            }
            return 3
        }
        
        func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            if (section == 0) {
                return ("Active Sessions")
            } else if (section == 2) {
                return ("My Friends")
            }
            return ""
        }
        
        func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
            let header: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
            header.contentView.backgroundColor = UIColor.grayColor()
            header.textLabel!.textColor = UIColor.whiteColor()
            header.textLabel!.textAlignment = NSTextAlignment.Center
        }
        
        
        func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let cell: ControlPanelCell = tableView.dequeueReusableCellWithIdentifier("ControlPanelCell", forIndexPath: indexPath) as! ControlPanelCell
            cell.friendName.text = "Pyke S."
            cell.friendStatus.layer.cornerRadius = 3;
            cell.friendStatus.layer.masksToBounds = true;
            if (indexPath.section == 0) {
                tableView.rowHeight = 60
                cell.friendStatus.backgroundColor = UIColor.greenColor()
                cell.friendStatusLabel.text = "Currently Tracking Location"
            } else if (indexPath.section == 1) {
                tableView.rowHeight = 60
                cell.friendStatus.backgroundColor = UIColor.blueColor()
                cell.friendStatusLabel.text = "Currently Sharing My Location"
            } else {
                tableView.rowHeight = 44
                cell.friendStatus.removeFromSuperview()
                cell.friendStatusLabel.removeFromSuperview()
                
                
            }
            return cell
        }
    }
    
    
    // Mark: Table View Delegate
    
    extension ControlPanelViewController: UITableViewDelegate {
        func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
            
        }
        
    }

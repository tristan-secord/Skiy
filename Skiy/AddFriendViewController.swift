//
//  AddFriendViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-08-11.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

protocol AddFriendDelegate {
    func hideAddFriend()
}

class User {
    var firstName : String = ""
    var lastName : String = ""
    var userName : String = ""
    
    init (_ first_name: String, last_name: String, user_name:String) {
        self.firstName = first_name
        self.lastName = last_name
        self.userName = user_name
    }
}

class AddFriendViewController: UIViewController {
    
    typealias Payload = [String: AnyObject]
    @IBOutlet weak var searchResult: UITableView!
    @IBOutlet weak var findFriend: UISearchBar!
    var delegate: AddFriendDelegate?
    let httpHelper = HTTPHelper()
    var friends = Array<User>()

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewWidth = view.frame.size.width
        let viewHeight = view.frame.size.height
        
        //instantiate search panel
        let searchPanel = UINib(nibName: "AddFriend", bundle: nil).instantiateWithOwner(self, options: nil)[0] as! UIView
        searchPanel.frame = CGRectMake(0, 0, viewWidth, viewHeight)
        
        //add searchPanel
        view.addSubview(searchPanel)
        
        //hide table view and set self to delegate
        searchResult.hidden = true
        findFriend.delegate = self
        searchResult.delegate = self
        searchResult.dataSource = self
        searchResult.registerNib(UINib(nibName: "FindFriendsCell", bundle: nil), forCellReuseIdentifier: "FindFriendsCell")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
        delegate?.hideAddFriend()
    }
    
    func searchFriends(searchBarText: String) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("findFriend", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPTokenAuth)
        
        // 3. Send the request Body
        httpRequest.HTTPBody = "{\"search_text\":\"\(searchBarText)\"}".dataUsingEncoding(NSUTF8StringEncoding)

        // 4. Send the request
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            if error != nil {
                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert(errorMessage as String)
                return
            }
            
            var json : Array<Payload>!
            do {
                json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? Array<Payload>
            } catch let error as NSError {
                print(error.localizedDescription)
            }
            
            for i in 0 ..< json.count {
                let item = json[i],
                firstName = item["first_name"] as? String,
                lastName = item["last_name"] as? String,
                username = item["username"] as? String
                
                let friend = User(firstName!, last_name: lastName!, user_name: username!)
                self.friends.append(friend)
                self.searchResult.reloadData()
            }
        })
    }
    
    func displayErrorAlert(message: String) {
        let errorAlert = UIAlertController(title: "", message: message, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil);
        let CancelAction = UIAlertAction(title: "Cancel", style: .Destructive) { action in
            self.findFriend.text = ""
        }
        
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
}

extension AddFriendViewController : UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        //hide keyboard
        if searchBar.isFirstResponder() {
            searchBar.resignFirstResponder()
        }
        
        //get and show results
        if searchBar.text! != "" {
             searchFriends(searchBar.text!)
        }
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == "" {
            searchResult.hidden = true
        } else {
            searchResult.hidden = false
        }
    }
}

extension AddFriendViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: FindFriendsCell = tableView.dequeueReusableCellWithIdentifier("FindFriendsCell", forIndexPath: indexPath) as! FindFriendsCell
        cell.friendName.text = "\(friends[indexPath.row].firstName) \(friends[indexPath.row].lastName)"
        cell.friendUsername.text = friends[indexPath.row].userName
        cell.friendStatusLabel.text = "Add Friend"
        cell.friendStatusImage.image = UIImage(named: "Add")
        //cell.addFriendView.backgroundColor = UIColor.blueColor()
        cell.addFriendView.layer.cornerRadius = 5;
        cell.addFriendView.layer.masksToBounds = true;
        tableView.rowHeight = 56
        
        return cell
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return(1)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.friends.count)
    }
}
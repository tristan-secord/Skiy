//
//  AddFriendViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-08-11.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit
import CoreData

protocol AddFriendDelegate {
    func hideAddFriend()
    func updateFriendsTableView()
}

class User {
    var id : Int
    var firstName : String = ""
    var lastName : String = ""
    var userName : String = ""
    var status : String = ""
    
    init (_ id: Int, first_name: String, last_name: String, user_name:String) {
        self.id = id
        self.firstName = first_name
        self.lastName = last_name
        self.userName = user_name
    }
}

class AddFriendViewController: UIViewController {
    typealias Payload = [String: AnyObject]
    @IBOutlet weak var findFriend: CustomTextField!
    @IBOutlet weak var searchResult: UITableView!
    @IBOutlet weak var searchFriendPrompt: UIView!
    var delegate: AddFriendDelegate?
    let httpHelper = HTTPHelper()
    var friends = Array<User>()
    var coreDataResults = [NSManagedObject]()
    var friendsColor: UIColor = Colors.colorWithHexString("#4CD964") // green
    var pendingColor: UIColor = Colors.colorWithHexString("#8E8E93") // gray
    var requestColor: UIColor = Colors.colorWithHexString("#5AC8FB") // blue
    let appDelegate =
        UIApplication.shared.delegate as! AppDelegate

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewWidth = view.frame.size.width
        let viewHeight = view.frame.size.height
        
        //instantiate search panel
        let searchPanel = UINib(nibName: "AddFriend", bundle: nil).instantiate(withOwner: self, options: nil)[0] as! UIView
        searchPanel.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
        view.layer.shadowOpacity = 0.8
        
        //Adding Blur Effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
        view.insertSubview(blurView, at: 0)
        
        //add searchpanel ontop
        view.addSubview(searchPanel)

        //hide table view and set self to delegate
        searchResult.isHidden = true
        searchFriendPrompt.isHidden = false
        findFriend.delegate = self
        searchResult.delegate = self
        searchResult.dataSource = self
        searchResult.register(UINib(nibName: "FindFriendsCell", bundle: nil), forCellReuseIdentifier: "FindFriendsCell")
        
        findFriend.layer.shadowColor = UIColor.black.cgColor
        findFriend.layer.shadowOffset = CGSize(width: 1, height: 1)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        delegate?.hideAddFriend()
    }
    
    func searchFriends(_ searchBarText: String) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("findFriend", method: "POST",
                                                  authType: HTTPRequestAuthType.httpTokenAuth)
        
        // 3. Send the request Body
        httpRequest.httpBody = "{\"search_text\":\"\(searchBarText)\"}".data(using: String.Encoding.utf8)

        // 4. Send the request
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            if error != nil {
//                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert((error?.localizedDescription)! as String)
                return
            }
            
            var json : Array<Payload>!
            do {
                json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? Array<Payload>
            } catch let error as NSError {
                print(error.localizedDescription)
            }
            
            if json.count <= 0 {
                self.displayErrorAlert("Could not find any users by this name")
            }
            
            for i in 0 ..< json.count {
                let item = json[i],
                id = item["id"] as? Int,
                firstName = item["first_name"] as? String,
                lastName = item["last_name"] as? String,
                username = item["username"] as? String
                
                let friend = User(id!, first_name: firstName!, last_name: lastName!, user_name: username!)
                self.friends.append(friend)
            }
            self.updateSearchResults()
        })
    }
    
    func addFriend(_ username: String, status: String, selectedCell: FindFriendsCell?) {
        let httpRequest = httpHelper.buildRequest("addFriend", method: "POST",
                                                  authType: HTTPRequestAuthType.httpTokenAuth)
        httpRequest.httpBody = "{\"username\":\"\(username)\"}".data(using: String.Encoding.utf8)
        
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            if error != nil {
//                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert((error?.localizedDescription)! as String)
            } else {
                self.friendAdded(username, status: status, selectedCell: selectedCell)
            }
        })
    }
    
    func removeFriend(_ username: String, selectedCell: FindFriendsCell?) {
        let httpRequest = httpHelper.buildRequest("removeFriend", method: "POST",
                                                  authType: HTTPRequestAuthType.httpTokenAuth)
        httpRequest.httpBody = "{\"username\":\"\(username)\"}".data(using: String.Encoding.utf8)
        
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            if error != nil {
//                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert((error?.localizedDescription)! as String)
            } else {
                self.friendRemoved(username, selectedCell: selectedCell)
            }
        })
    }
    
    func friendAdded(_ username: String, status: String, selectedCell: FindFriendsCell?) {
        var newStatus : String
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Friend")
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Friend", in: managedContext)
        
        //Configure predicate
        let predicate : NSPredicate = NSPredicate(format: "username == %@", NSString(string: username))
        
        // Configure Fetch Request
        fetchRequest.entity = entityDescription
        fetchRequest.predicate = predicate
        
        switch (status) {
        case "pending":
            //update TableView Cell
            if (selectedCell != nil) {
                selectedCell!.friendStatusLabel.text = "Friends"
                selectedCell!.friendStatusLabel.textColor = self.friendsColor
            }
            
            //update Core Data
            newStatus = "friends"
            break
        default:
            //update TableView Cell
            if (selectedCell != nil) {
                selectedCell!.friendStatusLabel.text = "Requested"
                selectedCell!.friendStatusLabel.textColor = self.pendingColor
            }
            
            //update Core Data
            newStatus = "requested"
            break
        }
        
        var friend: NSManagedObject
        
        //update Core Data
        do {
            let result = try managedContext.fetch(fetchRequest)
            if result.count > 0 {
                friend = result[0] as! NSManagedObject
                friend.setValue(newStatus, forKey: "status")
            } else {
                friend = NSManagedObject(entity: entityDescription!,
                                         insertInto: managedContext)
                if let userIndex = friends.index(where: { $0.userName == username }) {
                    let user = friends[userIndex]
                    friend.setValue(user.firstName, forKey: "first_name")
                    friend.setValue(user.lastName, forKey: "last_name")
                    friend.setValue(user.userName, forKey: "username")
                    friend.setValue(newStatus, forKey: "status")
                    friend.setValue(user.id, forKey: "id")
                    friend.setValue(Date(), forKey: "updated_at")
                }
            }
            do {
                try friend.managedObjectContext?.save()
            } catch let error as NSError  {
                print("Could not save \(error), \(error.userInfo)")
            }
        } catch {
            let fetchError = error as NSError
            print(fetchError)
        }        
        self.delegate?.updateFriendsTableView()
    }
    
    func friendRemoved(_ username: String, selectedCell: FindFriendsCell?) {
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Friend")

        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Friend", in: managedContext)
        
        //Configure predicate
        let predicate : NSPredicate = NSPredicate(format: "username == %@", NSString(string: username))
        
        // Configure Fetch Request
        fetchRequest.entity = entityDescription
        fetchRequest.predicate = predicate
        
        if (selectedCell != nil) {
            selectedCell!.friendStatusLabel.text = "Add Friend"
            selectedCell!.friendStatusLabel.textColor = self.requestColor
        }
        
        //update Core Data
        do {
            let result = try managedContext.fetch(fetchRequest)
            if result.count > 0 {
                let friend = result[0] as! NSManagedObject
                managedContext.delete(friend)
                do {
                    try managedContext.save()
                } catch let error as NSError  {
                    print("Could not save \(error), \(error.userInfo)")
                }
            }
        } catch {
            let fetchError = error as NSError
            print(fetchError)
        }
        
        self.delegate?.updateFriendsTableView()
    }
    
    func displayErrorAlert(_ message: String) {
        let errorAlert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default, handler: nil);
        let CancelAction = UIAlertAction(title: "Cancel", style: .destructive) { action in
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
        
        self.present(errorAlert, animated: true, completion: nil)
    }
    
    func updateSearchResults() {
        for i in 0..<coreDataResults.count {
            if let userIndex = friends.index(where: { $0.id == coreDataResults[i].value(forKey: "id") as! Int }) {
                friends[userIndex].status = coreDataResults[i].value(forKey: "status") as! String
            }
        }
        self.searchResult.reloadData()
    }
}

extension AddFriendViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if friends.count != 0 {
            self.friends.removeAll()
        }
        
        //get and show results
        if textField.text! != "" {
            coreDataResults = searchCoreData(textField.text!)!
            self.searchFriends(textField.text!)
            self.searchResult.reloadData()
            searchResult.isHidden = false
            searchFriendPrompt.isHidden = true
            return true
        } else {
            searchResult.isHidden = true
            searchFriendPrompt.isHidden = false
            return true
        }
    }
    
    
    func searchCoreData(_ searchBarText: String) -> [NSManagedObject]? {
        let managedContext = appDelegate.managedObjectContext
        
        // Initialize Fetch Request
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Friend")
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Friend", in: managedContext)
        
        //Configure predicate
        let predicate : NSPredicate = NSPredicate(format: "first_name == %@", NSString(string: searchBarText))
        
        // Configure Fetch Request
        fetchRequest.entity = entityDescription
        fetchRequest.predicate = predicate
        
        do {
            let result = try managedContext.fetch(fetchRequest)
            return (result as? [NSManagedObject])!
        } catch {
            let fetchError = error as NSError
            print(fetchError)
        }
        
        return nil
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.text! == "" {
            searchResult.isHidden = true
            searchFriendPrompt.isHidden = false
        } else {
            searchResult.isHidden = false
            searchFriendPrompt.isHidden = true
        }
    }
}

extension AddFriendViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: FindFriendsCell = tableView.dequeueReusableCell(withIdentifier: "FindFriendsCell", for: indexPath) as! FindFriendsCell
        cell.friendName.text = "\(friends[(indexPath as NSIndexPath).row].firstName) \(friends[(indexPath as NSIndexPath).row].lastName)"
        cell.friendUsername.text = friends[(indexPath as NSIndexPath).row].userName
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        switch friends[(indexPath as NSIndexPath).row].status {
        case "":
            cell.friendStatusLabel.text = "Add Friend"
            cell.friendStatusLabel.textColor = self.requestColor
            break
        case "pending":
            cell.friendStatusLabel.text = "Pending"
            cell.friendStatusLabel.textColor = self.pendingColor
            break
        case "requested":
            cell.friendStatusLabel.text = "Requested"
            cell.friendStatusLabel.textColor = self.pendingColor
            break
        default:
            cell.friendStatusLabel.text = "Friends"
            cell.friendStatusLabel.textColor = self.friendsColor
            break
        }
        tableView.rowHeight = 56
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return(1)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.friends.count)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var alert : UIAlertController
        var OKAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        let CancelAction = UIAlertAction(title: "Cancel", style: .destructive, handler: nil)

        let cell = tableView.cellForRow(at: indexPath) as? FindFriendsCell
        switch (cell!.friendStatusLabel.text!) {
            
        case "Pending":
            alert = UIAlertController(title: "\(cell!.friendName.text!)", message: "\(cell!.friendName.text!) has sent you a friend request. Would you like to accept this request?", preferredStyle: .alert)
            OKAction = UIAlertAction(title: "Accept", style: .default) { action in
                self.addFriend(cell!.friendUsername.text!, status: cell!.friendStatusLabel.text!, selectedCell: cell!)
            }
            break
            
        case "Requested":
            alert = UIAlertController(title: "\(cell!.friendName.text!)", message:  "Friend request has already been sent, please wait for \(cell!.friendName.text!) to accept this request.", preferredStyle: .alert)
            break
            
        case "Friends":
            alert = UIAlertController(title: "\(cell!.friendName.text!)", message: "You and \(cell!.friendName.text!) are already friends. Would you like to remove this user from your friends?", preferredStyle: .alert)
            OKAction = UIAlertAction(title: "Remove", style: .default) {action in
                self.removeFriend(cell!.friendUsername.text!, selectedCell: cell)
            }
            break
            
        default:
            alert = UIAlertController(title: "\(cell!.friendName.text!)", message: "Send friend request to \(cell!.friendName.text!)?", preferredStyle: .alert)
            OKAction = UIAlertAction(title: "Request", style: .default) {action in
                self.addFriend(cell!.friendUsername.text!, status: cell!.friendStatusLabel.text!, selectedCell: cell!)
            }
            break
        }
        
        alert.addAction(OKAction)
        alert.addAction(CancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
}

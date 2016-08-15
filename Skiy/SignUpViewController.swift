//
//  SignUpViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-07-15.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

enum errorTitles: String {
    case woops = "Woops!"
    case uhoh = "Uh Oh..."
    case notquite = "Not Quite!"
}

protocol SignUpViewControllerDelegate {
    func hideSignUp(animation: Bool)
}

class SignUpViewController: UIViewController {
    
    @IBOutlet weak var pageContainer: UIView!
    @IBOutlet weak var CancelButton: UIButton!
    @IBOutlet weak var SignUpButton: UIButton!
    
    @IBOutlet weak var formActionsView: UIView!
    
    var signUpPageVC : SignUpPageViewController?
    var signUpName : SignUpNameVC?
    var signUpEmail : SignUpEmailVC?
    var signUpPassword : SignUpPasswordVC?
    var delegate : SignUpViewControllerDelegate?
    let httpHelper = HTTPHelper()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor(white: 0.5, alpha: 0.5)
                
        formActionsView.layer.cornerRadius = 10;
        formActionsView.layer.masksToBounds = true;
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SignUpViewController.keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SignUpViewController.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
    }
    
    let containerSegueName = "signUpSegue"
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == containerSegueName {
            signUpPageVC = segue.destinationViewController as? SignUpPageViewController
            signUpPageVC!.signUpVC = self
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        clearFields()
    }
    
    func clearFields() {
        //signUpName!.clearFields()
        //signUpEmail!.clearFields()
        //signUpPassword!.clearFields()
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            if view.frame.origin.y == 0{
                self.view.frame.origin.y -= keyboardSize.height
            }
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            if view.frame.origin.y != 0 {
                self.view.frame.origin.y += keyboardSize.height
            }
        }
    }
    
    func displayAlertMessage(alertTitle:String, alertDescription:String) -> Void {
        // display alert message
        let alert = UIAlertController(title: alertTitle, message: alertDescription, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(OKAction)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func displayErrorAlert (message: String) {
        let errorAlert = UIAlertController(title: "", message: message, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil);
        let CancelAction = UIAlertAction(title: "Cancel", style: .Destructive) { action in
            self.delegate?.hideSignUp(false)
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
    
    func makeSignUpRequest(firstName:String, lastName:String, userEmail:String, username:String, userPassword:String) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("signup", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPBasicAuth)
        
        // 2. Password is encrypted with the API key
        let encrypted_password = AESCrypt.encrypt(userPassword, password: HTTPHelper.API_AUTH_PASSWORD)
        
        // 3. Send the request Body
        httpRequest.HTTPBody = "{\"first_name\":\"\(firstName)\",\"last_name\":\"\(lastName)\",\"username\":\"\(username)\",\"email\":\"\(userEmail)\",\"password\":\"\(encrypted_password)\"}".dataUsingEncoding(NSUTF8StringEncoding)
        
        // 4. Send the request
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            if error != nil {
                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert(errorMessage as String)
                
                return
            }
            self.displayAlertMessage("Welcome to Skiy!", alertDescription: "Your account has been created. Sign in and start tracking!")
            self.delegate?.hideSignUp(false)
        })
    }
    
    /********** Sign Up Actions *********/
    @IBAction func SignUpClicked(sender: UIButton) {
        if ((signUpPageVC!.getSignUpNameVC() == nil) || (signUpPageVC!.getSignUpEmailVC() == nil) || (signUpPageVC!.getSignUpPasswordVC() == nil)) {
            displayErrorAlert("Looks like your missing some information...")
        } else {
            signUpName = signUpPageVC?.getSignUpNameVC()
            signUpEmail = signUpPageVC?.getSignUpEmailVC()
            signUpPassword = signUpPageVC?.getSignUpPasswordVC()
            
            if self.signUpName!.firstName.isFirstResponder() {
                self.signUpName!.firstName.resignFirstResponder()
            }
            
            if self.signUpName!.lastName.isFirstResponder() {
                self.signUpName!.lastName.resignFirstResponder()
            }
            
            if self.signUpEmail!.email.isFirstResponder() {
                self.signUpEmail!.email.resignFirstResponder()
            }
            
            if self.signUpEmail!.username.isFirstResponder() {
                self.signUpEmail!.username.resignFirstResponder()
            }
            
            if self.signUpPassword!.password.isFirstResponder() {
                self.signUpPassword!.password.resignFirstResponder()
            }
            
            if self.signUpPassword!.verifyPassword.isFirstResponder() {
                self.signUpPassword!.verifyPassword.resignFirstResponder()
            }
            
            if (self.signUpName!.firstName.text!.characters.count) <= 0 ||
                (self.signUpName!.lastName.text!.characters.count) <= 0 ||
                (self.signUpEmail!.email.text!.characters.count) <= 0 ||
                (self.signUpEmail!.username.text!.characters.count) <= 0 ||
                (self.signUpPassword!.password.text!.characters.count) <= 0 ||
                (self.signUpPassword!.verifyPassword.text!.characters.count) <= 0 {
                displayErrorAlert("Looks like your missing some information...")
            } else if (signUpPassword!.password.text! != signUpPassword!.verifyPassword.text!) {
                displayErrorAlert("Go double check those passwords, somethings not right...")
                //password.layer.borderWidth = 1
                //verifyPassword.layer.borderWidth = 1
            } else if (!signUpEmail!.email.text!.containsString("@") || !signUpEmail!.email.text!.containsString(".")) {
                displayErrorAlert("Is that an email address? Let's try that again.")
                //email.layer.borderWidth = 1
            } else if (signUpPassword!.password.text!.characters.count < 6 || signUpPassword!.password.text!.characters.count > 30){
                displayErrorAlert("Your password must be between 6 and 30 characters long.")
                //password.layer.borderWidth = 1
            } else {
                makeSignUpRequest(self.signUpName!.firstName.text!, lastName: self.signUpName!.lastName.text!, userEmail: signUpEmail!.email.text!, username: signUpEmail!.username.text!, userPassword: signUpPassword!.password.text!)
            }
        }
    }
    
    
    @IBAction func CancelClicked(sender: UIButton) {
        delegate?.hideSignUp(true)
    }
}

private extension UIStoryboard {
    class func mainStoryboard() -> UIStoryboard { return UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()) }
    
    class func signUpPageViewController() -> SignUpPageViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("SignUpPageViewController") as? SignUpPageViewController
    }
    
    class func signUpNameVC() -> SignUpNameVC? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("SignUpNameVC") as? SignUpNameVC
    }
}


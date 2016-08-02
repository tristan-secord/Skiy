//
//  SignUpViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-07-15.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

protocol SignUpViewControllerDelegate {
    func hideSignUp(animation: Bool)
}

class SignUpViewController: UIViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var CancelButton: UIButton!
    @IBOutlet weak var SignUpButton: UIButton!
    @IBOutlet weak var formActionsView: UIView!
    @IBOutlet weak var formView: UIView!
    @IBOutlet weak var firstName: UITextField!
    @IBOutlet weak var lastName: UITextField!
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var verifyPassword: UITextField!
    var delegate : SignUpViewControllerDelegate?
    
    let httpHelper = HTTPHelper()
    
    enum errorTitles: String {
        case woops = "Woops!"
        case uhoh = "Uh Oh..."
        case notquite = "Not Quite!"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor(white: 0.5, alpha: 0.5)
        
        formView.layer.cornerRadius = 10;
        formView.layer.masksToBounds = true;
        
        formActionsView.layer.cornerRadius = 10;
        formActionsView.layer.masksToBounds = true;
        
        firstName.layer.borderColor = UIColor.redColor().CGColor
        firstName.layer.cornerRadius = 5
        firstName.addTarget(self, action: #selector(SignUpViewController.textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
        
        lastName.layer.borderColor = UIColor.redColor().CGColor
        lastName.layer.cornerRadius = 5
        lastName.addTarget(self, action: #selector(SignUpViewController.textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
        
        email.layer.borderColor = UIColor.redColor().CGColor
        email.layer.cornerRadius = 5
        email.addTarget(self, action: #selector(SignUpViewController.textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
        
        password.layer.borderColor = UIColor.redColor().CGColor
        password.layer.cornerRadius = 5
        password.addTarget(self, action: #selector(SignUpViewController.textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
        
        verifyPassword.layer.borderColor = UIColor.redColor().CGColor
        verifyPassword.layer.cornerRadius = 5
        verifyPassword.addTarget(self, action: #selector(SignUpViewController.textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        clearFields()
        self.activityIndicator.hidden = true
    }
    
    func clearFields() {
        firstName.text = ""
        firstName.layer.borderWidth = 0
        lastName.text = ""
        lastName.layer.borderWidth = 0
        email.text = ""
        email.layer.borderWidth = 0
        password.text = ""
        password.layer.borderWidth = 0
        verifyPassword.text = ""
        verifyPassword.layer.borderWidth = 0
    }
    
    func textFieldDidChange(textField: UITextField) {
        textField.layer.borderWidth = 0
    }
    
    func highlightEmptyFields() {
        if (firstName.text!.characters.count) <= 0 {
            firstName.layer.borderWidth = 1
        } else {
            firstName.layer.borderWidth = 0
        }
        
        if (lastName.text!.characters.count) <= 0 {
            lastName.layer.borderWidth = 1
        } else {
            lastName.layer.borderWidth = 0
        }
        
        if (email.text!.characters.count) <= 0 {
            email.layer.borderWidth = 1
        } else {
            email.layer.borderWidth = 0
        }
        
        if (password.text!.characters.count) <= 0 {
            password.layer.borderWidth = 1
        } else {
            password.layer.borderWidth = 0
        }
        
        if (verifyPassword.text!.characters.count) <= 0 {
            verifyPassword.layer.borderWidth = 1
        } else {
            verifyPassword.layer.borderWidth = 0
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
    
    func makeSignUpRequest(firstName:String, lastName:String, userEmail:String, userPassword:String) {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("signup", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPBasicAuth)
        
        // 2. Password is encrypted with the API key
        let encrypted_password = AESCrypt.encrypt(userPassword, password: HTTPHelper.API_AUTH_PASSWORD)
        
        // 3. Send the request Body
        httpRequest.HTTPBody = "{\"first_name\":\"\(firstName)\",\"last_name\":\"\(lastName)\",\"email\":\"\(userEmail)\",\"password\":\"\(encrypted_password)\"}".dataUsingEncoding(NSUTF8StringEncoding)
        
        // 4. Send the request
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            if error != nil {
                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert(errorMessage as String)
                
                return
            }
            self.displayAlertMessage("Welcome to Skiy!", alertDescription: "Your account has been created. Sign in and start tracking!")
        })
    }
    
    /********** Sign Up Actions *********/
    @IBAction func SignUpClicked(sender: UIButton) {
        self.activityIndicator.hidden = false
        
        if self.firstName.isFirstResponder() {
            self.firstName.resignFirstResponder()
        }
        
        if self.lastName.isFirstResponder() {
            self.lastName.resignFirstResponder()
        }
        
        if self.email.isFirstResponder() {
            self.email.resignFirstResponder()
        }
        
        if self.password.isFirstResponder() {
            self.password.resignFirstResponder()
        }
        
        if self.verifyPassword.isFirstResponder() {
            self.verifyPassword.resignFirstResponder()
        }
        
        if (firstName.text!.characters.count) <= 0 ||
            (self.lastName.text!.characters.count) <= 0 ||
            (self.email.text!.characters.count) <= 0 ||
            (self.password.text!.characters.count) <= 0 ||
            (self.verifyPassword.text!.characters.count) <= 0 {
            
            self.activityIndicator.hidden = true
            
            displayErrorAlert("Looks like your missing some information...")
            highlightEmptyFields()
        } else if (password.text! != verifyPassword.text!) {
            self.activityIndicator.hidden = true
            displayErrorAlert("Go double check those passwords, somethings not right...")
            password.layer.borderWidth = 1
            verifyPassword.layer.borderWidth = 1
        } else if (!email.text!.containsString("@") || !email.text!.containsString(".")) {
            self.activityIndicator.hidden = true
            displayErrorAlert("Is that an email address? Let's try that again.")
            email.layer.borderWidth = 1
        } else if (password.text!.characters.count < 6 || password.text!.characters.count > 30){
            self.activityIndicator.hidden = true
            displayErrorAlert("Your password must be between 6 and 30 characters long.")
            password.layer.borderWidth = 1
        } else {
            makeSignUpRequest(self.firstName.text!, lastName: self.lastName.text!, userEmail: self.email.text!,
                              userPassword: self.password.text!)
            self.activityIndicator.hidden = true
            self.delegate?.hideSignUp(false)
        }
    }
    
    
    @IBAction func CancelClicked(sender: UIButton) {
        delegate?.hideSignUp(true)
    }
}

//
//  SignInViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-07-08.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

protocol SignInViewControllerDelegate {
    func SignedIn()
    func showSignUp()
}

class SignInViewController: UIViewController {
    
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    var delegate : SignInViewControllerDelegate?
    var blurView = UIImageView()
    
    let httpHelper = HTTPHelper()
    
    enum errorTitles: String {
        case woops = "Woops!"
        case uhoh = "Uh Oh..."
        case notquite = "Not Quite!"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewWidth = self.view.frame.width
        let viewHeight = self.view.frame.height
        
        let signInView = UINib(nibName: "SignInView", bundle: nil).instantiateWithOwner(self, options: nil)[0] as! UIView
        signInView.frame = CGRectMake(0, 0, viewWidth, viewHeight)
        signInView.alpha = 0.8
                
        let blurEffect = UIBlurEffect(style: .Light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRectMake(0, 0, viewWidth, viewHeight)
        view.insertSubview(blurView, atIndex: 10000)
        
        view.addSubview(signInView)
    }
    
    func displayErrorAlert (message: String) {
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
    
    func makeSignInRequest(userEmail:String, userPassword:String) {
        // Create HTTP request and set request Body
        let httpRequest = httpHelper.buildRequest("signin", method: "POST",
                                                  authType: HTTPRequestAuthType.HTTPBasicAuth)
        let encrypted_password = AESCrypt.encrypt(userPassword, password: HTTPHelper.API_AUTH_PASSWORD)
        
        let device_id = UIDevice.currentDevice().identifierForVendor
        
        httpRequest.HTTPBody = "{\"email\":\"\(userEmail)\",\"password\":\"\(encrypted_password)\", \"device_id\":\"\(device_id)\"}".dataUsingEncoding(NSUTF8StringEncoding);
        
        httpHelper.sendRequest(httpRequest, completion: {(data:NSData!, error:NSError!) in
            // Display error
            if error != nil {
                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert(errorMessage as String)
                
                return
            }
            
            self.updateUserLoggedInFlag()
            
            do {
                if let responseDict = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
                    // save API AuthToken and ExpiryDate in Keychain
                    self.saveApiTokenInKeychain(responseDict)
                } else {
                    print("Could not parse response dictionary!")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        })
    }
    
    func updateUserLoggedInFlag() {
        // Update the NSUserDefaults flag
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject("loggedIn", forKey: "userLoggedIn")
        defaults.synchronize()
    }
    
    func saveApiTokenInKeychain(tokenDict:NSDictionary) {
        // Store API AuthToken and AuthToken expiry date in KeyChain
        tokenDict.enumerateKeysAndObjectsUsingBlock({ (dictKey, dictObj, stopBool) -> Void in
            let myKey = dictKey as! String
            let myObj = dictObj as! String
            
            if myKey == "api_authtoken" {
                KeychainAccess.setPassword(myObj, account: "Auth_Token", service: "KeyChainService")
            }
            
            if myKey == "authtoken_expiry" {
                KeychainAccess.setPassword(myObj, account: "Auth_Token_Expiry", service: "KeyChainService")
            }
        })
        self.delegate?.SignedIn()
    }
    
    
    /******Sign In Page Actions******/
    @IBAction func SignInButtonPressed(sender: UIButton) {
        // resign the keyboard for text fields
        if self.username.isFirstResponder() {
            self.username.resignFirstResponder()
        }
        
        if self.password.isFirstResponder() {
            self.password.resignFirstResponder()
        }
        
        // validate presense of required parameters
        if (self.username.text!.characters.count) > 0 &&
            (self.password.text!.characters.count) > 0 {
            makeSignInRequest(self.username.text!, userPassword: self.password.text!)
        } else {
            displayErrorAlert("Looks like your missing some vital information...")
        }
    }
    
    
    @IBAction func SignUpButtonPressed(sender: UIButton) {
        self.delegate?.showSignUp()
    }
    
    @IBAction func ForgotPasswordButtonPressed(sender: UIButton) {
    }


}

private extension UIStoryboard {
    
    class func mainStoryboard() -> UIStoryboard { return UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()) }
    
    class func signUpViewController() -> SignUpViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("SignUpViewController") as? SignUpViewController
    }
}

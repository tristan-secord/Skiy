//
//  SignInViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-07-08.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit
import SwiftSpinner
import CoreData

protocol SignInViewControllerDelegate {
    func SignedIn()
}

class SignInViewController: UIViewController {
    
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var signInFields: UIView!
    @IBOutlet weak var skiyTitle: UIImageView!
    @IBOutlet weak var signInScrollView: UIScrollView!
    typealias Payload = [String: AnyObject]
    
    enum controllers {
        case signIn
        case signUp
    }
    
    var currentController = controllers.signIn
    
    //Sign up outlets
    @IBOutlet weak var signUp_continue: UIButton!
    @IBOutlet weak var signUp_first_textField: CustomTextField!
    @IBOutlet weak var signUp_second_textField: CustomTextField!
    @IBOutlet weak var signUp_first_icon: UIImageView!
    @IBOutlet weak var signUp_second_icon: UIImageView!
    @IBOutlet weak var signUp_back_button: UIButton!
    @IBOutlet weak var signUp_signIn: UIButton!
    
    var signUpViewController : UIViewController? = nil
    var signUp_first_name : String? = nil
    var signUp_last_name : String? = nil
    var signUp_username : String? = nil
    var signUp_email : String? = nil
    var signUp_password : String? = nil
    var signUp_verifyPassword : String? = nil
    
    
    var delegate : SignInViewControllerDelegate?
    var blurView = UIImageView()
    let defaults = UserDefaults.standard
    let httpHelper = HTTPHelper()
    var signUpIndex: Int = 0
    
    enum errorTitles: String {
        case woops = "Woops!"
        case uhoh = "Uh Oh..."
        case notquite = "Not Quite!"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let viewWidth = self.view.frame.width
        let viewHeight = self.view.frame.height
        
        let signInView = UINib(nibName: "SignInView", bundle: nil).instantiate(withOwner: self, options: nil)[0] as! UIView
        signInView.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
                
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
        view.insertSubview(blurView, at: 10000)
        
        view.addSubview(signInView)
        
        //set textfields delegates to self
        self.username.delegate = self
        self.password.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func displayErrorAlert (_ title: String?, message: String) {
        let errorAlert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default, handler: nil);
        
        errorAlert.addAction(OKAction)
        
        if (title == nil) {
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
        } else {
            errorAlert.title = title
        }
        
        self.present(errorAlert, animated: true, completion: nil)
    }
    
    func makeSignInRequest(_ userEmail:String, userPassword:String) {
        // Create HTTP request and set request Body
        let httpRequest = httpHelper.buildRequest("signin", method: "POST",
                                                  authType: HTTPRequestAuthType.httpBasicAuth)
        
        let encrypted_password = AESCrypt.encrypt(userPassword, password: HTTPHelper.API_AUTH_PASSWORD)
        
        let deviceToken = defaults.object(forKey: "deviceToken") as! String
        
        httpRequest.httpBody = "{\"email\":\"\(userEmail)\",\"password\":\"\(encrypted_password!)\", \"device_id\":\"\(deviceToken)\"}".data(using: String.Encoding.utf8);
        
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            self.hideSpinner()
            // Display error
            if error != nil {
//                let errorMessage = self.httpHelper.getErrorMessage(error!)
                self.displayErrorAlert(nil, message: (error?.localizedDescription)! as String)
                
                return
            }
            
            self.updateUserLoggedInFlag()
            
            do {
                if let responseDict = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary {
                    
                    // save API AuthToken and ExpiryDate in Keychain
                    if let user = responseDict["user"] as? NSDictionary {
                        self.saveApiTokenInKeychain(user)
                    }
                    if let notifications = responseDict["notifications"] as? Array<Payload> {
                        self.saveNotifications(notifications)
                    }
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
        defaults.set("loggedIn", forKey: "userLoggedIn")
        defaults.synchronize()
        self.username.text! = ""
        self.password.text! = ""
    }
    
    func saveApiTokenInKeychain(_ tokenDict:NSDictionary) {
        // Store API AuthToken and AuthToken expiry date in KeyChain
        tokenDict.enumerateKeysAndObjects({ (dictKey, dictObj, stopBool) -> Void in
            let myKey = dictKey as! String
            let myObj = dictObj as! String
            
            switch (myKey) {
            case "api_authtoken" :
                KeychainAccess.setPassword(myObj, account: "Auth_Token", service: "KeyChainService")
                break
            case "authtoken_expiry":
                KeychainAccess.setPassword(myObj, account: "Auth_Token_Expiry", service: "KeyChainService")
                break
            case "first_name":
                self.defaults.set(myObj, forKey: "first_name")
                break
            case "last_name":
                self.defaults.set(myObj, forKey: "last_name")
                break
            default:
                break
            }
        })
        self.delegate?.SignedIn()
    }
    
    func saveNotifications(_ notificationsDict: Array<Payload>) {
        let appDelegate =
            UIApplication.shared.delegate as! AppDelegate
        
        let managedContext = appDelegate.managedObjectContext
        
        // Create Entity Description
        let entityDescription = NSEntityDescription.entity(forEntityName: "Notification", in: managedContext)
        
        //IF NEED TO ADD TIME ZONE INFO TO DATE FORMATTER HERE
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                
        for i in 0..<notificationsDict.count {
            let item = notificationsDict[i]
            let notification = NSManagedObject(entity: entityDescription!,
                                     insertInto: managedContext)
            notification.setValue(item["sender_id"] as? Int, forKey: "id")
            notification.setValue(item["category"] as? String, forKey: "category")
            notification.setValue(item["payload"] as? String, forKey: "payload")
            
            let expiry: Date?
            if item["expiry"] as? String != nil {
                expiry = dateFormatter.date(from: item["expiry"] as! String)! as Date
            } else {
                expiry = nil
            }
            notification.setValue(expiry, forKey: "expiry")
            
            let created: Date?
            if item["created_at"] as? String != nil {
                created = dateFormatter.date(from: item["created_at"] as! String)! as Date
            } else {
                created = nil
            }
            notification.setValue(created, forKey: "created")
            
            do {
                try notification.managedObjectContext?.save()
            } catch let error as NSError {
                print("Could not save \(error), \(error.userInfo)")
            }
        }
    }
    
    /******Sign In Page Actions******/
    @IBAction func SignInButtonPressed(_ sender: UIButton) {
        // resign the keyboard for text fields
        if self.username.isFirstResponder {
            self.username.resignFirstResponder()
        }
        
        if self.password.isFirstResponder {
            self.password.resignFirstResponder()
        }

        // validate presense of required parameters
        if (self.username.text!.characters.count) > 0 &&
            (self.password.text!.characters.count) > 0 {
            showSpinner("Authenticating user account")
            makeSignInRequest(self.username.text!, userPassword: self.password.text!)
        } else {
            displayErrorAlert(nil, message: "Looks like your missing some vital information...")
        }
    }
    
    
    @IBAction func SignUpButtonPressed(_ sender: UIButton) {
        self.showSignUp()
    }
    
    func showSignUp() {
        signUpViewController = UIViewController()
        signUpViewController!.view = UINib(nibName: "SignUpView", bundle: nil).instantiate(withOwner: self, options: nil)[0] as! UIScrollView
        signUpViewController!.view.frame = CGRect(x: signInFields.frame.origin.x, y: signInFields.frame.origin.y, width: self.signInFields.frame.width, height: self.signInFields.frame.height)
        self.signInFields.isHidden = true
        self.view.addSubview(signUpViewController!.view)
        
        //button aesthetics
        signUp_back_button.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        signUp_back_button.isEnabled = false
        
        //set textfield delegates
        self.signUp_first_textField.delegate = self
        self.signUp_second_textField.delegate = self
        signUpIndex = 0
        currentController = controllers.signUp
    }
    
    //Hiding keyboard on touch view or return
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        self.view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    
    @IBAction func ForgotPasswordButtonPressed(_ sender: UIButton) {
    }
    
    //sign up actions
    
    @IBAction func continue_clicked(_ sender: UIButton) {
        //hide keyboard
        self.view.endEditing(true)
        
        switch (self.signUpIndex) {
        case 0:
            //0. Increment sign up counter
            self.signUpIndex += 1
            
            //1. Save entered values
            signUp_first_name = signUp_first_textField.text!
            signUp_last_name = signUp_second_textField.text!
            
            //2. Load old values if available
            if self.signUp_username != nil { signUp_first_textField.text = self.signUp_username }
            else { signUp_first_textField.text = "" }
            if self.signUp_email != nil { signUp_second_textField.text = self.signUp_email }
            else { signUp_second_textField.text = "" }
        
            //3. Set new placeholders for text fields
            signUp_first_textField.placeholder = "Username"
            signUp_second_textField.placeholder = "Email"
            
            //4. Set new images for text fields
            signUp_first_icon.image = UIImage(named: "ID Card")
            signUp_second_icon.image = UIImage(named: "Email")
            
            //5. Enable back button
            signUp_back_button.isEnabled = true
            
            //6. Set text fields
            setTextFields(self.signUpIndex)
            break;
        case 1:
            //0. Increment sign up counter
            self.signUpIndex += 1
            
            //1. Save entered values
            signUp_username = signUp_first_textField.text!
            signUp_email = signUp_second_textField.text!
            
            //2. Dont load old values - always make them retype password
            signUp_first_textField.text = ""
            signUp_second_textField.text = ""
            
            //3. Set new placeholders for text fields
            signUp_first_textField.placeholder = "Password"
            signUp_second_textField.placeholder = "Verify Password"
            
            //4. Set new images for text fields
            signUp_first_icon.image = UIImage(named: "Password")
            signUp_second_icon.image = UIImage(named: "Password Check")
            
            //5. Change continue button to SIGN UP
            signUp_continue.setTitle("Sign Up", for: UIControlState())
            
            //6. Set text fields
            self.setTextFields(self.signUpIndex)
            break;
        default:
            showSpinner("Validating user fields.")
            signUp_password = signUp_first_textField.text!
            signUp_verifyPassword = signUp_second_textField.text!
            completeSignUp()
            break;
        }
    }
    
    func showSpinner(_ message: String) {
        self.view.isHidden = true
        SwiftSpinner.setTitleFont(UIFont(name: "Hero", size: 18.0))
        _ = SwiftSpinner.show(message, animated: true)
    }
    
    func hideSpinner() {
        self.view.isHidden = false
        SwiftSpinner.hide()
    }
    
    func completeSignUp() {
        if signUp_first_textField.isFirstResponder {
            signUp_first_textField.resignFirstResponder()
        }
        if signUp_second_textField.isFirstResponder {
            signUp_second_textField.resignFirstResponder()
        }
        
        if (signUp_first_name == nil || signUp_first_name!.characters.count <= 0 ||
            signUp_last_name == nil || signUp_last_name!.characters.count <= 0 ||
            signUp_username == nil || signUp_username!.characters.count <= 0 ||
            signUp_email == nil || signUp_email!.characters.count <= 0 ||
            signUp_password == nil || signUp_password!.characters.count <= 0 ||
            signUp_verifyPassword == nil || signUp_verifyPassword!.characters.count <= 0) {
                hideSpinner()
                displayErrorAlert(nil, message: "Looks like your missing some information...")
        } else if (signUp_password != signUp_verifyPassword) {
            hideSpinner()
            displayErrorAlert(nil, message: "Go double check those passwords, somethings not right...")
        } else if (!signUp_email!.contains("@") || !signUp_email!.contains(".")) {
            hideSpinner()
            displayErrorAlert(nil, message: "Is that an email address? Let's try that again.")
        } else if (signUp_password!.characters.count < 6 || signUp_password!.characters.count > 30){
            hideSpinner()
            displayErrorAlert(nil, message: "Your password must be between 6 and 30 characters long.")
        } else {
            self.makeSignUpRequest()
        }
    }
    
    func makeSignUpRequest() {
        // 1. Create HTTP request and set request header
        let httpRequest = httpHelper.buildRequest("signup", method: "POST",
                                                  authType: HTTPRequestAuthType.httpBasicAuth)
        
        // 2. Password is encrypted with the API key
        let encrypted_password = AESCrypt.encrypt(signUp_password!, password: HTTPHelper.API_AUTH_PASSWORD)
        
        // 3. Send the request Body
        httpRequest.httpBody = "{\"first_name\":\"\(signUp_first_name!)\",\"last_name\":\"\(signUp_last_name!)\",\"username\":\"\(signUp_username!)\",\"email\":\"\(signUp_email!)\",\"password\":\"\(encrypted_password!)\"}".data(using: String.Encoding.utf8)
        
        // 4. Send the request
        httpHelper.sendRequest(httpRequest as URLRequest, completion: {(data:Data?, error:Error?) in
            self.hideSpinner()
            if error != nil {
//                let errorMessage = self.httpHelper.getErrorMessage(error)
                self.displayErrorAlert(nil, message: (error?.localizedDescription)! as String)
                
                return
            }
            self.displayErrorAlert("Welcome to Skiy!", message: "Your account has been created. Sign in and start tracking!")
            self.hideSignUp()
        })
    }

    @IBAction func signUp_back_button_click(_ sender: UIButton) {
        //hide keyboard
        self.view.endEditing(true)
        
        switch (self.signUpIndex) {
        case 2:
            //0. Decrement sign up counter
            self.signUpIndex -= 1
            
            //1. Load old values if available
            if self.signUp_username != nil { self.signUp_first_textField.text = self.signUp_username }
            else { signUp_first_textField.text = "" }
            if self.signUp_email != nil { self.signUp_second_textField.text = self.signUp_email }
            else { signUp_second_textField.text = "" }
            
            //2. Update text field placeholders
            signUp_first_textField.placeholder = "Username"
            signUp_second_textField.placeholder = "Email"
            
            //3. Set text field icons
            signUp_first_icon.image = UIImage(named: "ID Card")
            signUp_second_icon.image = UIImage(named: "Email")
            
            //4. Re-set sign up button to continue
            signUp_continue.setTitle("Continue", for: UIControlState())
            
            //5. Set text fields
            self.setTextFields(self.signUpIndex)
            break;
        case 1:
            //0. Decrement sign up counter
            self.signUpIndex -= 1
            
            //1. Save username and email
            signUp_username = signUp_first_textField.text!
            signUp_email = signUp_second_textField.text!
            
            //2. Load old values if available
            if self.signUp_first_name != nil { self.signUp_first_textField.text = self.signUp_first_name }
            else { signUp_first_textField.text = "" }
            if self.signUp_last_name != nil { self.signUp_second_textField.text = self.signUp_last_name }
            else { signUp_second_textField.text = "" }
            
            //3. Update text field placeholders
            signUp_first_textField.placeholder = "First Name"
            signUp_second_textField.placeholder = "Last Name"
            
            //4. Set text field icons
            signUp_first_icon.image = UIImage(named: "User")
            signUp_second_icon.image = UIImage(named: "Dog Tag")
            
            //5. Disable back button
            signUp_back_button.isEnabled = false
            
            //6. Set textFields
            self.setTextFields(self.signUpIndex)
            break;
        default:
            break;
        }
    }
    
    
    func setTextFields(_ index: Int) {
        switch (index) {
        case 2:
            //password and verify password
            signUp_first_textField.isSecureTextEntry = true
            signUp_first_textField.autocapitalizationType = .none
            signUp_first_textField.keyboardType = .default
            signUp_second_textField.isSecureTextEntry = true
            signUp_second_textField.autocapitalizationType = .none
            signUp_second_textField.keyboardType = .default
            break;
        case 1:
            //username and email
            signUp_first_textField.isSecureTextEntry = false
            signUp_first_textField.autocapitalizationType = .none
            signUp_first_textField.keyboardType = .default
            signUp_second_textField.isSecureTextEntry = false
            signUp_second_textField.autocapitalizationType = .none
            signUp_second_textField.keyboardType = .emailAddress
            break;
        default:
            //first and last name
            signUp_first_textField.isSecureTextEntry = false
            signUp_first_textField.autocapitalizationType = .allCharacters
            signUp_first_textField.keyboardType = .default
            signUp_second_textField.isSecureTextEntry = false
            signUp_second_textField.autocapitalizationType = .allCharacters
            signUp_second_textField.keyboardType = .default
            break;
        }
    }
    
    @IBAction func signUpSignIn_clicked(_ sender: UIButton) {
        self.hideSignUp()
    }
    
    func hideSignUp() {
        clearSignUpData()
        //remove any data left in
        signUpViewController!.view.removeFromSuperview()
        signInFields.isHidden = false
        currentController = controllers.signIn
    }
    
    func clearSignUpData() {
        //clear text fields
        signUp_first_textField.text = ""
        signUp_first_textField.placeholder = "First Name"
        signUp_second_textField.text = ""
        signUp_second_textField.placeholder = "Second Name"
        signUp_first_icon.image = UIImage(named: "User")
        signUp_second_icon.image = UIImage(named: "Dog Tag")

        //clear saved Data
        signUp_first_name = nil
        signUp_last_name = nil
        signUp_username = nil
        signUp_email = nil
        signUp_password = nil
        signUp_verifyPassword = nil
    }
    
    func keyboardWillShow(_ notification: Notification) {
        var scrollView: UIScrollView = signInScrollView
        
        if currentController == controllers.signUp {
            scrollView = self.signUpViewController!.view as! UIScrollView
        }
        
        var userInfo = (notification as NSNotification).userInfo!
        var keyboardFrame:CGRect = (userInfo[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)
        
        var contentInset:UIEdgeInsets = scrollView.contentInset
        contentInset.bottom = keyboardFrame.size.height
        scrollView.contentInset = contentInset
    }
    
    func keyboardWillHide(_ notification: Notification) {
        var scrollView: UIScrollView = signInScrollView
        if currentController == controllers.signUp {
            scrollView = self.signUpViewController!.view as! UIScrollView
        }
        
        let contentInset:UIEdgeInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInset
    }
}

extension SignInViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
}


private extension UIStoryboard {
    
    class func mainStoryboard() -> UIStoryboard { return UIStoryboard(name: "Main", bundle: Bundle.main) }
    
}

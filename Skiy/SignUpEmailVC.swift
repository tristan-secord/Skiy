//
//  SignUpEmailVC.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-08-04.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

class SignUpEmailVC: UIViewController {

    @IBOutlet weak var formView: UIView!
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var email: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        formView.layer.cornerRadius = 10;
        formView.layer.masksToBounds = true;
        
        username.layer.borderColor = UIColor.redColor().CGColor
        username.layer.cornerRadius = 5
        username.addTarget(self, action: #selector(textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
        
        
        email.layer.borderColor = UIColor.redColor().CGColor
        email.layer.cornerRadius = 5
        email.addTarget(self, action: #selector(textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func textFieldDidChange(textField: UITextField) {
        textField.layer.borderWidth = 0
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (username.text!.characters.count) <= 0 {
            username.layer.borderWidth = 1
        } else {
            username.layer.borderWidth = 0
        }
        
        if (email.text!.characters.count) <= 0 {
            email.layer.borderWidth = 1
        } else {
            email.layer.borderWidth = 0
        }
    }
    
    func clearFields() {
        username.text = ""
        email.text = ""
        username.layer.borderWidth = 0
        email.layer.borderWidth = 0
    }
}

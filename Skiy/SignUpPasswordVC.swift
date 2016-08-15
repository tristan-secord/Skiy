//
//  SignUpPasswordVC.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-08-04.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

class SignUpPasswordVC: UIViewController {

    @IBOutlet weak var formView: UIView!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var verifyPassword: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        formView.layer.cornerRadius = 10;
        formView.layer.masksToBounds = true;
        
        password.layer.borderColor = UIColor.redColor().CGColor
        password.layer.cornerRadius = 5
        password.addTarget(self, action: #selector(textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
        
        
        verifyPassword.layer.borderColor = UIColor.redColor().CGColor
        verifyPassword.layer.cornerRadius = 5
        verifyPassword.addTarget(self, action: #selector(textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func textFieldDidChange(textField: UITextField) {
        textField.layer.borderWidth = 0
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
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
    
    func clearFields() {
        password.text = ""
        verifyPassword.text = ""
        password.layer.borderWidth = 0
        verifyPassword.layer.borderWidth = 0
    }
}

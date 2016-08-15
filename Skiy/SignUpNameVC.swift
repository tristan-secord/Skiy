//
//  SignUpNameVC.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-08-03.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

class SignUpNameVC: UIViewController {

    @IBOutlet weak var firstName: UITextField!
    @IBOutlet weak var lastName: UITextField!
    @IBOutlet weak var formView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        formView.layer.cornerRadius = 10;
        formView.layer.masksToBounds = true;
        
        firstName.layer.borderColor = UIColor.redColor().CGColor
        firstName.layer.cornerRadius = 5
        firstName.addTarget(self, action: #selector(textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)

        
        lastName.layer.borderColor = UIColor.redColor().CGColor
        lastName.layer.cornerRadius = 5
        lastName.addTarget(self, action: #selector(textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func textFieldDidChange(textField: UITextField) {
        textField.layer.borderWidth = 0
    }
    
    func clearFields() {
        firstName.text = ""
        lastName.text = ""
        firstName.layer.borderWidth = 0
        lastName.layer.borderWidth = 0
    }
    
    func checkFields() -> Bool {
        if (((firstName.text!.characters.count) <= 0) && (lastName.text!.characters.count <= 0)) {
            firstName.layer.borderWidth = 1
            lastName.layer.borderWidth = 1
            return false
        } else {
            if (firstName.text!.characters.count) <= 0 {
                firstName.layer.borderWidth = 1
                return false
            }
            if (lastName.text!.characters.count) <= 0 {
                lastName.layer.borderWidth = 1
                return false
            }
        }
        
        firstName.layer.borderWidth = 0
        lastName.layer.borderWidth = 0
        return true
    }
}

//
//  CustomTextField.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-08-30.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import Foundation
import UIKit

class CustomTextField: UITextField {
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.layer.cornerRadius = 0
        self.layer.borderWidth = 1.0
        self.layer.borderColor = Colors.colorWithHexString("#404040").cgColor
        self.backgroundColor = Colors.colorWithHexString("#404040").withAlphaComponent(0.5)
        self.textColor = UIColor.white
        self.frame.size.height = 500
    }
}

//
//  CustomFloatingActionSheetController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-10-09.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import Foundation
import FloatingActionSheetController

class CustomFloatingActionSheetController {
    let actionSheet: FloatingActionSheetController
    
    init (actionGroup: FloatingActionGroup, animationStyle: FloatingActionSheetController.AnimationStyle) {
        self.actionSheet = FloatingActionSheetController(actionGroup: actionGroup, animationStyle: animationStyle)
        
        // Color of action sheet
        self.actionSheet.itemTintColor = UIColor.black
        // Color of title texts
        self.actionSheet.textColor = Colors.colorWithHexString(Colors.babyBlue())
        // Font of title texts
        self.actionSheet.font = UIFont(name: "Hero", size: 18.0)!
        // background dimming color
        self.actionSheet.dimmingColor = UIColor.gray.withAlphaComponent(0.8)
    }
}

//
//  NotificationCell.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-09-14.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import Foundation
import UIKit

class NotificationCell: UITableViewCell {
    @IBOutlet weak var senderName: UILabel!
    @IBOutlet weak var notificationExpiry: UILabel!
    @IBOutlet weak var notificationCategory: UILabel!
    @IBOutlet weak var newNotificationBubble: UIView!
}
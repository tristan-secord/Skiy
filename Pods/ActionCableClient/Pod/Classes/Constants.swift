//
//  Copyright (c) 2016 Daniel Rhodes <rhodes.daniel@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
//  USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import Accelerate

internal let ActionCableSerialQueue = dispatch_queue_create("com.ActionCableClient.SerialQueue", DISPATCH_QUEUE_SERIAL);
internal let ActionCableConcurrentQueue = dispatch_queue_create("com.ActionCableClient.Conccurent", DISPATCH_QUEUE_CONCURRENT)

internal enum Command {
    case Subscribe
    case Unsubscribe
    case Message
    
    var string : String {
        switch self {
        case .Subscribe: return "subscribe"
        case .Unsubscribe: return "unsubscribe"
        case .Message: return "message"
        }
    }
}

internal enum MessageType {
    case ConfirmSubscription
    case RejectSubscription
    case CancelSubscription
    case HibernateSubscription
    case Ping
    case Message
    case Welcome
    case Unrecognized
    
    var string: String {
        switch self {
            case .ConfirmSubscription: return "confirm_subscription"
            case .RejectSubscription: return "reject_subscription"
            case .Ping: return "ping"
            case .Welcome: return "welcome"
            case .Message: return "message" // STUB!
            case .CancelSubscription: return "cancel_subscription" // STUB!
            case .HibernateSubscription: return "hibernate_subscription" //STUB!
            case .Unrecognized: return "___unrecognized"
        }
    }
    
    init(string: String) {
        switch(string) {
            case MessageType.Welcome.string:
                self = MessageType.Welcome
            case MessageType.Ping.string:
                self = MessageType.Ping
            case MessageType.ConfirmSubscription.string:
                self = MessageType.ConfirmSubscription
            case MessageType.RejectSubscription.string:
                self = MessageType.RejectSubscription
            case MessageType.CancelSubscription.string:
                self = MessageType.CancelSubscription
            case MessageType.HibernateSubscription.string:
                self = MessageType.HibernateSubscription
            default:
                self = MessageType.Unrecognized
        }
    }
}

internal struct Message {
    var channelName : String?
    var actionName : String?
    var messageType : MessageType
    var data : AnyObject?
    var error: ErrorType?
    
    static func simple(channel: Channel, messageType: MessageType) -> Message {
        return Message(channelName: channel.name,
                        actionName: nil,
                       messageType: messageType,
                              data: nil,
                             error: nil)
    }
}

internal struct Action {
    var name : String
    var params: Dictionary<String, AnyObject>?
}

func exp2(x: [Double]) -> [Double] {
  var results = [Double](count: x.count, repeatedValue: 0.0)
  vvexp2(&results, x, [Int32(x.count)])
  
  return results
}


func clamp<T: Comparable>(value: T, lower: T, upper: T) -> T {
    return min(max(value, lower), upper)
}
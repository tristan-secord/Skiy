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

public typealias ChannelIdentifier = Dictionary<String, AnyObject>
public typealias OnReceiveClosure = ((AnyObject?, ErrorType?) -> (Void))

/// A particular channel on the server.
public class Channel: Hashable, Equatable {
    
    /// Name of the channel
    public var name : String
    
    /// Identifier
    public var identifier: Dictionary<String, AnyObject>?
    
    /// Auto-Subscribe to channel on initialization and re-connect?
    public var autoSubscribe : Bool
    
    /// Buffer actions
    /// If not subscribed, buffer actions and flush until after a subscribe
    public var shouldBufferActions : Bool
    
    /// Subscribed
    public var subscribed : Bool {
        return client.subscribed(name)
    }
    
    /// A block called when a message has been received on this channel.
    ///
    /// ```swift
    /// channel.onReceive = {(JSON : AnyObject?, error: ErrorType?) in
    ///   print("Received:", JSON, "Error:", error)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///     - object: Depends on what is sent. Usually a Dictionary.
    ///     - error: An error when decoding of the message failed.
    ///
    public var onReceive: ((AnyObject?, ErrorType?) -> Void)?
  
    /// A block called when the channel has been successfully subscribed.
    ///
    /// Note: This block will be called if the client disconnects and then
    /// reconnects again.
    ///
    /// ```swift
    /// channel.onSubscribed = {
    ///     print("Yay!")
    /// }
    /// ```
    public var onSubscribed: (() -> Void)?
    
    /// A block called when the channel was unsubscribed.
    ///
    /// Note: This block is also called if the server disconnects.
    public var onUnsubscribed: (() -> Void)?
    
    /// A block called when a subscription attempt was rejected
    /// by the server.
    public var onRejected: (() -> Void)?

    internal init(name: String, identifier: ChannelIdentifier?, client: ActionCableClient, autoSubscribe: Bool=true, shouldBufferActions: Bool=true) {
        self.name = name
        self.client = client
        self.autoSubscribe = autoSubscribe
        self.shouldBufferActions = shouldBufferActions
        self.identifier = identifier
    }
    
    public func onReceive(action:String, handler: (OnReceiveClosure)) -> Void {
        onReceiveActionHooks[action] = handler
    }
    
    /// Subscript for `action:`.
    ///
    /// Send an action to the server.
    ///
    /// Note: ActionCable does not give any confirmation or response that an
    /// action was succcessfully executed or received.
    ///
    /// ```swift
    /// channel['speak'](["message": "Hello, World!"])
    /// ```
    ///
    /// - Parameters:
    ///     - action: The name of the action (e.g. speak)
    /// - Returns: `true` if the action was sent.

    public subscript(name: String) -> (Dictionary<String, AnyObject>) -> ErrorType? {
        
        func executeParams(params : Dictionary<String, AnyObject>?) -> ErrorType?  {
            return action(name, params: params)
        }
        
        return executeParams
    }
    
    /// Send an action.
    ///
    /// Note: ActionCable does not give any confirmation or response that an
    /// action was succcessfully executed.
    ///
    /// ```swift
    /// channel.action("speak", ["message": "Hello, World!"])
    /// ```
    ///
    /// - Parameters:
    ///     - action: The name of the action (e.g. speak)
    ///     - params: A `Dictionary` of JSON encodable values.
    ///
    ///
    /// - Returns: A `TransmitError` if there were any issues sending the
    ///             message.

    public func action(name: String, params: [String: AnyObject]? = nil) -> ErrorType? {
        do {
            try (client.action(self, action: name, data: params))
        // Consume the error and return false if the error is a not subscribed
        // error and we are buffering the actions.
        } catch TransmitError.NotSubscribed where self.shouldBufferActions {
            
            dispatch_async(ActionCableSerialQueue, {
                self.actionBuffer.append(Action(name: name, params: params))
            })
            
            return TransmitError.NotSubscribed
        } catch {
            return error
        }
        
        return nil
    }
    
    /// Subscribe to the channel on the server.
    ///
    /// This should be unnecessary if autoSubscribe is `true`.
    ///
    /// ```swift
    /// channel.subscribe()
    /// ```
    public func subscribe() {
        client.subscribe(self)
    }
    
    /// Unsubscribe from the channel on the server.
    ///
    /// Upon unsubscribing, ActionCableClient will stop retaining this object.
    ///
    /// ```swift
    /// channel.unsubscribe()
    /// ```
    public func unsubscribe() {
        client.unsubscribe(self)
    }
    
    internal var onReceiveActionHooks: Dictionary<String, OnReceiveClosure> = Dictionary()
    internal unowned var client: ActionCableClient
    internal var actionBuffer: Array<Action> = Array()
    public let hashValue: Int = random()
}

public func ==(lhs: Channel, rhs: Channel) -> Bool {
  return (lhs.hashValue == rhs.hashValue) && (lhs.name == rhs.name)
}

extension Channel {
    internal func onMessage(message: Message) {
        switch message.messageType {
            case .Message:
                if let callback = self.onReceive {
                    dispatch_async(dispatch_get_main_queue(), { callback(message.data, message.error) })
                }
                
                if let actionName = message.actionName, let callback = self.onReceiveActionHooks[actionName] {
                    dispatch_async(dispatch_get_main_queue(), { callback(message.data, message.error) })
                }
            case .ConfirmSubscription:
                if let callback = self.onSubscribed {
                    dispatch_async(dispatch_get_main_queue(), callback)
                }
                
                self.flushBuffer()
            case .RejectSubscription:
                if let callback = self.onRejected {
                    dispatch_async(dispatch_get_main_queue(), callback)
                }
            case .HibernateSubscription:
              fallthrough
            case .CancelSubscription:
                if let callback = self.onUnsubscribed {
                    dispatch_async(dispatch_get_main_queue(), callback)
                }
            default: break
        }
    }
    
    internal func flushBuffer() {
        dispatch_sync(ActionCableSerialQueue, {() -> Void in
            // Bail out if the parent is gone for whatever reason
            while let action = self.actionBuffer.popLast() {
                self.action(action.name, params: action.params)
            }
        })
    }
}

extension Channel {
    func copyWithZone(zone: NSZone) -> AnyObject! {
        assert(false, "This class doesn't implement NSCopying. ")
        return nil
    }
    
    func copy() -> AnyObject! {
        assert(false, "This class doesn't implement NSCopying")
        return nil
    }
}

extension Channel: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "ActionCable.Channel<\(hashValue)>(name: \"\(self.name)\" subscribed: \(self.subscribed))"
    }
}

extension Channel: CustomPlaygroundQuickLookable {
    public func customPlaygroundQuickLook() -> PlaygroundQuickLook {
        return PlaygroundQuickLook.Text(self.name)
    }
}
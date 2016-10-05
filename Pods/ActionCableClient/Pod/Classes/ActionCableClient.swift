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
import Starscream

public class ActionCableClient {
    
    //MARK: Socket
    public private(set) var socket : WebSocket
    
    /// Reconnection Strategy
    ///
    /// If a disconnection occurs, reconnnectionStrategy determines and calculates
    /// the time interval at which a retry happens.
    public var reconnectionStrategy : RetryStrategy = .LogarithmicBackoff(maxRetries: 5, maxIntervalTime: 30.0)
    
    //MARK: Global Callbacks
    /// Will Connect
    ///
    /// Called when the client is about to connect
    public var willConnect: (() -> Void)?
    /// On Connected
    ///
    /// Called when the client has connected
    public var onConnected: (() -> Void)?
    /// On Disconnected
    ///
    /// Called when the client disconnected
    public var onDisconnected: ((ConnectionError?) -> Void)?
    /// Will Reconnect
    ///
    /// Called when the client is about to reconnect
    public var willReconnect: (() -> Bool)?
    /// On Rejected
    ///
    /// Called when the client has been rejected from connecting.
    public var onRejected: (() -> Void)?
    /// On Ping
    ///
    /// Called when the server pings the client
    public var onPing: (() -> Void)?
    
    // MARK: Channel Callbacks
    public var onChannelSubscribed: ((Channel) -> (Void))?
    public var onChannelUnsubscribed: ((Channel) -> (Void))?
    public var onChannelRejected: ((Channel) -> (Void))?
    public var onChannelReceive: ((Channel, AnyObject?, ErrorType?) -> Void)?
    
    //MARK: Properties
    public var connected : Bool { return socket.isConnected }
    public var URL: NSURL { return socket.currentURL }
    
    public var headers : [String: String] {
        get { return socket.headers }
        set { socket.headers = newValue }
    }
    
    public var origin : String? {
        get { return socket.origin }
        set { socket.origin = newValue }
    }
  
    /// Initialize an ActionCableClient.
    ///
    /// Each client represents one connection to the server.
    ///
    /// This client must be retained somewhere, such as on the app delegate.
    ///
    ///  ```swift
    ///  let client = ActionCableClient(URL: NSURL(string: "ws://localhost:3000/cable")!)
    ///  ```
    public required init(URL: NSURL) {
        /// Setup Initialize Socket
        socket = WebSocket(url: URL)
        setupWebSocket()
    }
    
    /// Connect with the server
    public func connect() -> ActionCableClient {
        dispatch_async(dispatch_get_main_queue()) {
          if let callback = self.willConnect {
            callback()
          }
          
          dispatch_async(ActionCableConcurrentQueue) {
            self.socket.connect()
            self.reconnectionState = nil
          }
        }
  
        return self
    }
  
    /// Disconnect from the server.
    public func disconnect() {
        manualDisconnectFlag = true
        socket.disconnect(forceTimeout: 0)
    }
    
    internal func reconnect() {
        dispatch_async(dispatch_get_main_queue()) {
            var shouldReconnect = true
            if let callback = self.willReconnect {
                shouldReconnect = callback()
            }
            
            // Reconnection has been cancelled
            if (!shouldReconnect) {
                self.reconnectionState = nil
                return
            }
          
            if let callback = self.willConnect {
              callback()
            }
            
            dispatch_async(ActionCableConcurrentQueue) {
                self.socket.connect()
            }
        }
    }

    internal func transmit(channel: Channel, command: Command, data: Dictionary<String, AnyObject>?) throws -> Bool {
        // First let's see if we can even encode this data
        
        let JSONString = try JSONSerializer.serialize(channel, command: command, data: data)
        
        //
        // If it's a message, let's see if we are subscribed first.
        //
        // It is important to check this one first, because if we are buffering
        // actions, we want to tell the channel it's not subscribed rather
        // than we are not connected.
        //
        
        if (command == Command.Message) {
            guard channel.subscribed else { throw TransmitError.NotSubscribed }
        }
        
        // Let's check if we are connected.
        guard connected else { throw TransmitError.NotConnected }
        
        socket.writeString(JSONString as String!)
        
        return true
    }
    
    // MARK: Properties
    private var channelArray = Array<Channel>()
    private(set) var channels = Dictionary<String, Channel>()
    private var unconfirmedChannels = Dictionary<String, Channel>()
    
    /// Reconnection State
    /// This keeps our reconnection state around while we try to reconnect
    private var reconnectionState : RetryHandler?
    
    /// Manual Disconnect Flag
    ///
    /// This flag tells us if we decided to manually disconnect
    /// or it happened upstream.
    internal var manualDisconnectFlag : Bool = false
}

//MARK: Channel Creation
extension ActionCableClient {
    /// Create and subscribe to a channel.
    ///
    /// - Parameters:
    ///     - name: The name of the channel. The name must match the class name on the server exactly. (e.g. RoomChannel)
    /// - Returns: a Channel
    @warn_unused_result(message="You must hold on to the Channel returned from a create(_:)")
    public func create(name: String) -> Channel {
        let channel = create(name, identifier: nil, autoSubscribe: true, bufferActions: true)
        return channel
    }
    
    /// Create and subscribe to a channel.
    /// 
    /// - Parameters:
    ///     - name: The name of the channel. The name must match the class name on the server exactly. (e.g. RoomChannel)
    ///     - identifier: An optional Dictionary with parameters to be passed into the Channel on each request
    ///     - autoSubscribe: Whether to automatically subscribe to the channel. Defaults to true.
    /// - Returns: a Channel
    @warn_unused_result(message="You must hold on to the Channel returned from a create(_:)")
    public func create(name: String, identifier: ChannelIdentifier?, autoSubscribe: Bool=true, bufferActions: Bool=true) -> Channel {
        // Look in existing channels and return that
        if let channel = channels[name] { return channel }
        
        // Look in unconfirmed channels and return that
        if let channel = unconfirmedChannels[name] { return channel }
        
        // Otherwise create a new one
        let channel = Channel(name: name,
            identifier: identifier,
            client: self,
            autoSubscribe: autoSubscribe,
            shouldBufferActions: bufferActions)
      
        self.unconfirmedChannels[name] = channel
      
        if (channel.autoSubscribe) {
          subscribe(channel)
        }
        
        return channel
    }
    
    public subscript(name: String) -> Channel {
        let channel = create(name, identifier: nil, autoSubscribe: true, bufferActions: true)
        return channel
    }
}

// MARK: Channel Subscriptions
extension ActionCableClient {
    
    public func subscribed(name: String) -> Bool {
        return self.channels.keys.contains(name)
    }
    
    internal func subscribe(channel: Channel) {
        // Is it already added and subscribed?
        if let existingChannel = channels[channel.name] where (existingChannel == channel) {
          return
        }
      
        guard let channel = unconfirmedChannels[channel.name]
          else { debugPrint("[ActionCableClient] Internal inconsistency error!"); return }
      
        do {
            try self.transmit(channel, command: Command.Subscribe, data: nil)
        } catch {
            debugPrint(error)
        }
    }
    
    internal func unsubscribe(channel: Channel) {
        do {
            try self.transmit(channel, command: Command.Unsubscribe, data: nil)
            
            let message = Message(channelName: channel.name,
                                   actionName: nil,
                                  messageType: MessageType.CancelSubscription,
                                         data: nil,
                                        error: nil)
            
            onMessage(message)
        } catch {
            // There is a chance here the server could be down or not connected.
            // However, at this point the client will need to reconnect anyways
            // and will not resubscribe to the channel.
            debugPrint(error)
        }
    }
    
    internal func action(channel: Channel, action: String, data: Dictionary<String, AnyObject>?) throws -> Bool {
        var internalData : Dictionary<String, AnyObject>
        if let _ = data {
            internalData = data!
        } else {
            internalData = Dictionary()
        }
        
        internalData["action"] = action
        
        return try transmit(channel, command: Command.Message, data: internalData)
    }
}

// MARK: WebSocket Callbacks
extension ActionCableClient {
    
    private func setupWebSocket() {
        self.socket.onConnect    = { [weak self] in self!.didConnect() }
        self.socket.onDisconnect = { [weak self] (error: NSError?) in self!.didDisconnect(error) }
        self.socket.onText       = { [weak self] (text: String) in self!.onText(text) }
        self.socket.onData       = { [weak self] (data: NSData) in self!.onData(data) }
        self.socket.onPong       = { [weak self] in self!.didPong() }
    }
    
    private func didConnect() {
        
        // Clear Reconnection State: We successfull connected
        reconnectionState = nil
        
        if let callback = onConnected {
            dispatch_async(dispatch_get_main_queue(), callback)
        }
        
        for (_, channel) in self.unconfirmedChannels {
            if channel.autoSubscribe {
                self.subscribe(channel)
            }
        }
    }
    
    private func didDisconnect(error: NSError?) {
        
        var attemptReconnect: Bool = true
        var connectionError: ConnectionError?
        
        let channels = self.channels
        for (_, channel) in channels {
            let message = Message(channelName: channel.name, actionName: nil, messageType: MessageType.HibernateSubscription, data: nil, error: nil)
            onMessage(message)
        }
        
        // Attempt Reconnection?
        if let unwrappedError = error {
            connectionError = ConnectionError.ErrorForErrorCode(unwrappedError)
            attemptReconnect = connectionError!.recoverable
        }
        
        // Reconcile reconncetion attempt with manual disconnect
        attemptReconnect = !manualDisconnectFlag && attemptReconnect
        
        // disconnect() has not been called and error is
        // worthy of attempting a reconnect.
        if (attemptReconnect) {
            switch reconnectionStrategy {
            // We are going to need a retry handler (state machine) for these
            case .Linear, .ExponentialBackoff, .LogarithmicBackoff:
                if reconnectionState == nil {
                    reconnectionState = RetryHandler(strategy: reconnectionStrategy)
                }
                
                reconnectionState?.retry {[weak self] in
                    self?.reconnect()
                }
                
                return
            // if strategy is None, we don't want to reconnect
            case .None: break
            }
        }
        
        
        // Clear Reconnetion State
        reconnectionState = nil
        
        // Fire Callbacks
        if let callback = onDisconnected {
            // Clear the Connection Error on a manual disconnect
            // as it will not seem accurate
            if manualDisconnectFlag { connectionError = nil }
            
            dispatch_async(dispatch_get_main_queue(),{ callback(connectionError) })
        }
        
        // Reset Manual Disconnect Flag
        manualDisconnectFlag = false
    }
    
    private func didPong() {
        // This never seems to fire with ActionCable!
    }
    
    private func onText(text: String) {
        dispatch_async(ActionCableConcurrentQueue, { () -> Void in
            do {
                let message = try JSONSerializer.deserialize(text)
                self.onMessage(message)
            } catch {
                print("[ActionCableClient] Error decoding message: \(error)")
            }
        })
    }
    
    private func onMessage(message: Message) {
            switch(message.messageType) {
            case .Unrecognized:
                break
            case .Welcome:
                break
            case .Ping:
                if let callback = onPing {
                    dispatch_async(dispatch_get_main_queue(), callback)
                }
            case .Message:
                if let channel = channels[message.channelName!] {
                    // Notify Channel
                    channel.onMessage(message)
                    
                    if let callback = onChannelReceive {
                        dispatch_async(dispatch_get_main_queue(), { callback(channel, message.data, message.error) } )
                    }
                }
            case .ConfirmSubscription:
                if let channel = unconfirmedChannels.removeValueForKey(message.channelName!) {
                    self.channels.updateValue(channel, forKey: channel.name)
                    
                    // Notify Channel
                    channel.onMessage(message)
                    
                    if let callback = onChannelSubscribed {
                        dispatch_async(dispatch_get_main_queue(), { callback(channel) })
                    }
                }
            case .RejectSubscription:
                // Remove this channel from the list of unconfirmed subscriptions
                if let channel = unconfirmedChannels.removeValueForKey(message.channelName!) {
                    
                    // Notify Channel
                    channel.onMessage(message)
                    
                    if let callback = onChannelRejected {
                        dispatch_async(dispatch_get_main_queue(), { callback(channel) })
                    }
                }
            case .HibernateSubscription:
              if let channel = channels.removeValueForKey(message.channelName!) {
                // Add channel into unconfirmed channels
                unconfirmedChannels[channel.name] = channel
                
                // We want to treat this like an unsubscribe.
                fallthrough
              }
            case .CancelSubscription:
                if let channel = channels.removeValueForKey(message.channelName!) {
                    
                    // Notify Channel
                    channel.onMessage(message)
                    
                    if let callback = onChannelUnsubscribed {
                        dispatch_async(dispatch_get_main_queue(), { callback(channel) })
                    }
                }
            }
    }
    
    private func onData(data: NSData) {
        debugPrint("Received NSData from ActionCable.")
    }
}

extension ActionCableClient : CustomDebugStringConvertible {
    public var debugDescription : String {
            return "ActionCableClient(url: \"\(socket.currentURL)\" connected: \(socket.isConnected) id: \(unsafeAddressOf(self)))"
    }
}

extension ActionCableClient : CustomPlaygroundQuickLookable {
    public func customPlaygroundQuickLook() -> PlaygroundQuickLook {
        return PlaygroundQuickLook.URL(socket.currentURL.absoluteString)
    }
}

extension ActionCableClient {
    func copyWithZone(zone: NSZone) -> AnyObject! {
        assert(false, "This class doesn't implement NSCopying. ")
        return nil
    }
    
    func copy() -> AnyObject! {
        assert(false, "This class doesn't implement NSCopying")
        return nil
    }
}
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

internal class JSONSerializer {

    static let nonStandardMessageTypes: [MessageType] = [.Ping, .Welcome]
  
    static func serialize(channel : Channel, command: Command, data: Dictionary<String, AnyObject>?) throws -> String {
        
        do {
            var identifierDict : ChannelIdentifier
            if let identifier = channel.identifier {
                identifierDict = identifier
            } else {
                identifierDict = Dictionary()
            }
            
            identifierDict["channel"] = "\(channel.name)"
            
            let JSONData = try NSJSONSerialization.dataWithJSONObject(identifierDict, options: NSJSONWritingOptions(rawValue: 0))
            guard let identifierString = NSString(data: JSONData, encoding: NSUTF8StringEncoding)
                  else { throw SerializationError.JSON }
            
            var commandDict = [
                "command" : command.string,
                "identifier" : identifierString
            ]
            
            if let _ = data {
                let JSONData = try NSJSONSerialization.dataWithJSONObject(data!, options: NSJSONWritingOptions(rawValue: 0))
                guard let dataString = NSString(data: JSONData, encoding: NSUTF8StringEncoding)
                      else { throw SerializationError.JSON }
                
                commandDict["data"] = dataString
            }
            
            let CmdJSONData = try NSJSONSerialization.dataWithJSONObject(commandDict, options: NSJSONWritingOptions(rawValue: 0))
            guard let JSONString = NSString(data: CmdJSONData, encoding: NSUTF8StringEncoding)
                  else { throw SerializationError.JSON }
            
            return JSONString as String
        } catch {
            throw SerializationError.JSON
        }
    }
    
    static func deserialize(string: String) throws -> Message {
      
        do {
            guard let JSONData = string.dataUsingEncoding(NSUTF8StringEncoding) else { throw SerializationError.JSON }

            let JSONObj = try NSJSONSerialization.JSONObjectWithData(JSONData, options: .AllowFragments)
            
            var messageType: MessageType = .Unrecognized
            if let typeObj = JSONObj["type"], let typeString = typeObj as? String {
              messageType = MessageType(string: typeString)
            }
          
            var channelName: String?
            if let idDictObj = JSONObj["identifier"], let idObj = idDictObj {
                var idJSON: Dictionary<String, AnyObject>
                if let idString = idObj as? String {
                    guard let JSONIdentifierData = idString.dataUsingEncoding(NSUTF8StringEncoding)
                      else { throw SerializationError.JSON }
                  
                    if let JSON = try NSJSONSerialization.JSONObjectWithData(JSONIdentifierData, options: .AllowFragments) as? Dictionary<String, AnyObject> {
                        idJSON = JSON
                    } else {
                        throw SerializationError.JSON
                    }
                } else if let idJSONObj = idObj as? Dictionary<String, AnyObject> {
                    idJSON = idJSONObj
                } else {
                    throw SerializationError.ProtocolViolation
                }
                
                if let nameStr = idJSON["channel"], let name = nameStr as? String {
                  channelName = name
                }
            }
          
            switch messageType {
            // Subscriptions
            case .ConfirmSubscription, .RejectSubscription, .CancelSubscription, .HibernateSubscription:
                guard let _ = channelName
                  else { throw SerializationError.ProtocolViolation }
                
                return Message(channelName: channelName,
                               actionName:  nil,
                               messageType: messageType,
                               data: nil,
                               error: nil)
              
            // Welcome/Ping messages
            case .Welcome, .Ping:
                return Message(channelName: nil,
                               actionName: nil,
                               messageType: messageType,
                               data: nil,
                               error: nil)
            case .Message, .Unrecognized:
                var messageActionName : String?
                var messageValue      : AnyObject?
                var messageError      : ErrorType?
                
                do {
                    // No channel name was extracted from identifier
                    guard let _ = channelName
                        else { throw SerializationError.ProtocolViolation }
                    
                    // No message was extracted from identifier
                    guard let objVal = JSONObj["message"], let messageObj = objVal
                        else { throw SerializationError.ProtocolViolation }
                    
                    if let actionObj = messageObj["action"], let actionStr = actionObj as? String {
                        messageActionName = actionStr
                    }
                    
                    messageValue = messageObj
                } catch {
                  messageError = error
                }
                
                return Message(channelName: channelName!,
                               actionName: messageActionName,
                               messageType: MessageType.Message,
                               data: messageValue,
                               error: messageError)
            
          }
        } catch {
            throw error
        }
    }

}

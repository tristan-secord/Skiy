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

enum SerializationError : ErrorType {
    case JSON
    case Encoding
    case ProtocolViolation
}

public enum ReceiveError : ErrorType {
    case InvalidIdentifier
    case UnknownChannel
    case Decoding
    case InvalidFormat
    case UnknownMessageType
}

public enum TransmitError : ErrorType {
    case NotConnected
    case NotSubscribed
}

public enum ConnectionError : ErrorType {
    case NotFound(NSError)
    case GoingAway(NSError)
    case Refused(NSError)
    case SSLHandshake(NSError)
    case UnknownDomain(NSError)
    case Closed(NSError)
    case ProtocolViolation(NSError)
    case Unknown(NSError)
    case None
    
    var recoverable : Bool {
        switch self {
        case .NotFound: return false
        case .GoingAway: return false
        case .Refused: return true
        case .SSLHandshake: return false
        case .UnknownDomain: return false
        case .ProtocolViolation: return false
        case .Closed: return false
        case .Unknown: return true
        case .None: return false
        }
    }
    
    static func ErrorForErrorCode(error : NSError) -> ConnectionError {
        switch error.code {
        case 2: return ConnectionError.UnknownDomain(error)
        case 61: return ConnectionError.Refused(error)
        case 404: return ConnectionError.NotFound(error)
        case 1000: return ConnectionError.Closed(error)
        case 1002: return ConnectionError.ProtocolViolation(error)
        case 1003: return ConnectionError.ProtocolViolation(error)
        case 1005: return ConnectionError.Unknown(error)
        case 1007: return ConnectionError.ProtocolViolation(error)
        case 1008: return ConnectionError.ProtocolViolation(error)
        case 1009: return ConnectionError.ProtocolViolation(error)
        case 9847: return ConnectionError.SSLHandshake(error)
        default:
            return ConnectionError.Unknown(error)
        }
    }

}
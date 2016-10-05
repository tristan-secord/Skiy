# ActionCableClient

[![Version](https://img.shields.io/cocoapods/v/ActionCableClient.svg?style=flat)](http://cocoapods.org/pods/ActionCableClient)
[![License](https://img.shields.io/cocoapods/l/ActionCableClient.svg?style=flat)](http://cocoapods.org/pods/ActionCableClient)
[![Platform](https://img.shields.io/cocoapods/p/ActionCableClient.svg?style=flat)](http://cocoapods.org/pods/ActionCableClient)

[ActionCable](https://github.com/rails/rails/tree/master/actioncable) is a new WebSockets server being released with Rails 5 which makes it easy to add real-time features to your app. This Swift client makes it dead-simple to connect with that server, abstracting away everything except what you need to get going.

## Installation

ActionCableClient is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "ActionCableClient"
```

## Usage

### Get Started & Connect

```swift
import ActionCableClient

self.client = ActionCableClient(URL: NSURL(string: "ws://domain.tld/cable")!)

// Connect!
client.connect()

client.onConnected = {
    print("Connected!")
}

client.onDisconnected = {(error: ErrorType?) in
    print("Disconnected!")
}
```

### Subscribe to a Channel

```swift
// Create the Room Channel
let roomChannel = client.create("RoomChannel") //The channel name must match the class name on the server

```

### Channel Callbacks

```swift

// Receive a message from the server. Typically a Dictionary.
roomChannel.onReceive = { (JSON : AnyObject?, error : ErrorType?) in
    print("Received", JSON, error)
}

// A channel has successfully been subscribed to.
roomChannel.onSubscribed = {
    print("Yay!")
}

// A channel was unsubscribed, either manually or from a client disconnect.
roomChannel.onUnsubscribed = {
    print("Unsubscribed")
}

// The attempt at subscribing to a channel was rejected by the server.
roomChannel.onRejected = {
    print("Rejected")
}

```

### Perform an Action on a Channel

```swift
// Send an action
roomChannel["speak"](["message": "Hello, World!"])

// Alternate less magical way:
roomChannel.action("speak", ["message": "Hello, World!"])
```

### Authorization & Headers

```swift
// ActionCable can be picky about origins, so if you
// need it can be set here.
client.origin = "https://domain.tld/"

// If you need any sort of authentication, you 
// will not have cookies like you do in the browser,
// so set any headers here.
//
// These are available in the `Connection`
// on the server side.

client.headers = [
    "Authorization": "sometoken"
]
```

### Misc

```swift

client.onPing = {
    
}

```

For more documentation, see the [wiki](https://github.com/danielrhodes/Swift-ActionCableClient/wiki/Documentation)

## Requirements

[SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON): Used internally to ensure we are getting good responses from the server.

[Starscream](https://github.com/daltoniam/Starscream): The underlying WebSocket library.

## Author

Daniel Rhodes, rhodes.daniel@gmail.com

## License

ActionCableClient is available under the MIT license. See the LICENSE file for more info.

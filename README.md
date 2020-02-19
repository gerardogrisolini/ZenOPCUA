# ZenOPCUA

### Getting Started

#### Adding a dependencies clause to your Package.swift

```
dependencies: [
    .package(url: "https://github.com/gerardogrisolini/ZenOPCUA.git", from: "1.0.0")
]
```

#### Make client
```
import NIO
import ZenOPCUA

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
defer { try! eventLoopGroup.syncShutdownGracefully() }

let OPCUA = ZenOPCUA(host: "opcuaserver.com", port: 4840, reconnect: false, eventLoopGroup: eventLoopGroup)

OPCUA.onMessageReceived = { message in
    print(message.head)
}

OPCUA.onHandlerRemoved = {
    print("Handler removed")
}

OPCUA.onErrorCaught = { error in
    print(error.localizedDescription)
}
```

#### Connect to server
```
try OPCUA.connect(username: "test", password: "test").wait()
```

#### Disconnect client
```
try OPCUA.disconnect().wait()
```

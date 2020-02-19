# ZenOPCUA

### Getting Started

#### Adding a dependencies clause to your Package.swift

```
dependencies: [
    .package(url: "https://github.com/gerardogrisolini/ZenOPCUA.git", from: "1.0.6")
]
```

#### Make client
```
import NIO
import ZenOPCUA

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
defer { try! eventLoopGroup.syncShutdownGracefully() }

let OPCUA = ZenOPCUA(host: "www.OPCUAserver.org", port: 61716, reconnect: false, eventLoopGroup: eventLoopGroup)
try OPCUA.addTLS(cert: "certificate.crt", key: "private.key")
OPCUA.addKeepAlive(seconds: 10, destination: "/alive", message: "IoT Gateway is alive")

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

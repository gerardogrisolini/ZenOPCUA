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

let opcua = ZenOPCUA(
    endpoint: "opc.tcp://MacBook-Pro-di-Gerardo.local:53530/OPCUA/SimulationServer",
    reconnect: false,
    eventLoopGroup: eventLoopGroup
)

opcua.onHandlerRemoved = {
    print("OPCUA Client disconnected")
}
opcua.onErrorCaught = { error in
    print(error)
}

```

#### Connect to server
```
try opcua.connect().wait()
```

#### Browse
```
let items = try opcua.browse().wait()
for item in items {
    item.references.forEach { ref in
        print("\(ref.displayName.text): \(ref.nodeId)")
    }
}
```

#### Read value
```
let reads = [ReadValue(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2258))]
let readed = try opcua.read(nodes: reads).wait()
print(readed.first?.variant.value ?? "nil")
```

#### Write value
```
let writes: [WriteValue] = [
    WriteValue(
        nodeId: NodeIdString(nameSpace: 5, identifier: "MyLevel"),
        value: DataValue(variant: Variant(value: Double(21.0)))
    )
]
let writed = try opcua.write(nodes: writes).wait()
print(writed.first!)
```

#### Subscribe and MonitoredItems
```
let items: [ReadValue] = [
    ReadValue(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2258), monitoredId: 1),
    ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Counter"), monitoredId: 2),
    ReadValue(nodeId: NodeIdString(nameSpace: 5, identifier: "MyLevel"), monitoredId: 3)
]

opcua.onDataChanged = { data in
    data.forEach { dataChange in
        dataChange.dataChangeNotification.monitoredItems.forEach { item in
            if let node = items.first(where: { $0.monitoredId == item.monitoredId }) {
                print("\(node.nodeId): \(item.value.variant.value)")
            }
        }
    }
}

let subId = try opcua.createSubscription(requestedPubliscingInterval: 500).wait()
let results = try opcua.createMonitoredItems(subscriptionId: subId, itemsToCreate: items).wait()
results.forEach { result in
    print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
}

let deleted = try opcua.deleteSubscriptions(subscriptionIds: [subId]).wait()
deleted.forEach { result in
    print("deleteSubscription: \(result)")
}
```


#### Disconnect client
```
try OPCUA.disconnect().wait()
```

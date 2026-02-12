# ZenOPCUA

ZenOPCUA e' un client OPC UA scritto in Swift con backend SwiftNIO. Supporta browsing, read/write, subscription e sicurezza (sign/encrypt) con API sia EventLoopFuture che async/await.

## Caratteristiche

- Connessione OPC UA completa con sessione e reconnect
- Browse dell'address space
- Read/Write di nodi
- Subscriptions e MonitoredItems
- Security policy e message security mode (sign/encrypt)
- API EventLoopFuture + async/await

## Installazione (Swift Package Manager)

```swift
dependencies: [
    .package(url: "https://github.com/gerardogrisolini/ZenOPCUA.git", from: "1.0.0")
]
```

## Uso rapido

### Creazione client

```swift
import NIO
import ZenOPCUA

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
defer { try? eventLoopGroup.syncShutdownGracefully() }

let client = ZenOPCUA(
    eventLoopGroup: eventLoopGroup,
    endpointUrl: "opc.tcp://localhost:4840",
    applicationName: "ZenOPCUAClient",
    messageSecurityMode: .none,
    securityPolicy: .none
)

client.onHandlerActivated = {
    print("Client attivato")
}
client.onHandlerRemoved = {
    print("Client disconnesso")
}
client.onErrorCaught = { error in
    print("Errore: \(error)")
}
```

### Connessione

```swift
try client.connect(reconnect: false).wait()
```

### Browse

```swift
let root = [BrowseDescription(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2253))]
let results = try client.browse(nodes: root).wait()
for result in results {
    result.references.forEach { ref in
        print("\(ref.displayName.text): \(ref.nodeId)")
    }
}
```

### Read

```swift
let reads = [
    ReadValue(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2258))
]
let values = try client.read(nodes: reads).wait()
values.forEach { value in
    print(value.variant.value)
}
```

Nota: i read con status diverso da `UA_STATUSCODE_GOOD` non vengono restituiti.
In console viene stampato l'errore con il NodeId corrispondente.

### Write

```swift
let writes: [WriteValue] = [
    WriteValue(
        nodeId: NodeIdString(nameSpace: 5, identifier: "MyLevel"),
        value: DataValue(variant: Variant(value: Double(21.0)))
    )
]
let statuses = try client.write(nodes: writes).wait()
print(statuses)
```

### Subscription + MonitoredItems

```swift
let subscription = Subscription(
    requestedPubliscingInterval: 1000,
    requestedLifetimeCount: 1000,
    requesteMaxKeepAliveCount: 12,
    maxNotificationsPerPublish: 0,
    publishingEnabled: true
)

client.onDataChanged = { dataChanges in
    dataChanges.forEach { dataChange in
        dataChange.dataChangeNotification.monitoredItems.forEach { item in
            print("Handle \(item.clientHandle): \(item.value.variant.value)")
        }
    }
}

let subscriptionId = try client.createSubscription(subscription: subscription, startPublishing: true).wait()
let itemsToCreate: [MonitoredItemCreateRequest] = [
    MonitoredItemCreateRequest(
        itemToMonitor: ReadValue(nodeId: NodeIdString(nameSpace: 3, identifier: "Counter")),
        requestedParameters: MonitoringParameters(clientHandle: 1, samplingInterval: 250)
    ),
    MonitoredItemCreateRequest(
        itemToMonitor: ReadValue(nodeId: NodeIdNumeric(nameSpace: 3, identifier: 1002)),
        requestedParameters: MonitoringParameters(clientHandle: 2, samplingInterval: 250)
    )
]

let results = try client.createMonitoredItems(subscriptionId: subscriptionId, itemsToCreate: itemsToCreate).wait()
results.forEach { result in
    print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
}
```

### Disconnect

```swift
try client.disconnect(deleteSubscriptions: true).wait()
```

## Async/Await

Tutte le API principali hanno l'equivalente async/await.

```swift
import NIO
import ZenOPCUA

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
defer { try? eventLoopGroup.syncShutdownGracefully() }

let client = ZenOPCUA(
    eventLoopGroup: eventLoopGroup,
    endpointUrl: "opc.tcp://localhost:4840"
)

try await client.connect()

let nodes = [ReadValue(nodeId: NodeIdNumeric(nameSpace: 0, identifier: 2258))]
let results = try await client.read(nodes: nodes)
print("Letti: \(results.count)")

try await client.disconnect()
```

## Sicurezza

Per usare la sicurezza:

```swift
let client = ZenOPCUA(
    eventLoopGroup: eventLoopGroup,
    endpointUrl: "opc.tcp://localhost:4840",
    messageSecurityMode: .signAndEncrypt,
    securityPolicy: .basic256Sha256,
    certificate: "/path/to/client-cert.pem",
    privateKey: "/path/to/client-key.pem",
    includeServerThumbprintInOpn: true
)
```

## Note su errori di Read

- Se il server risponde con `BadNodeIdUnknown` o simili, il valore **non** viene restituito.
- In console viene stampato: `Read error: <StatusCode> for node <NodeId>`.
- Le diagnostiche del server vengono stampate come `Read diagnostic: ...` quando disponibili.

## Test

```bash
swift test
```

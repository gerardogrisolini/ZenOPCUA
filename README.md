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

L'init accetta anche opzioni di timeout configurabili:

```swift
let client = ZenOPCUA(
    eventLoopGroup: eventLoopGroup,
    endpointUrl: "opc.tcp://localhost:4840",
    connectTimeout: .seconds(20),      // default: 20 s (connessione TCP + handshake sessione)
    requestTimeout: .seconds(2),       // default: 2 s per ogni servizio (read, write, browse, subscription)
    verifyReceivedSignatures: false    // default: false (verifica delle firme in ingresso opt-in)
)
```

`verifyReceivedSignatures` e' disattivato per impostazione predefinita per ragioni di interoperabilita': alcuni server firmano i messaggi in modo che questo client non puo' validare, quindi la verifica in ingresso e' esplicitamente opzionale.

### Connessione

```swift
try client.connect(reconnect: false).wait()
```

`connect` accetta anche credenziali (`username:password:`) e la durata della sessione (`sessionLifetime`, in millisecondi).

### Browse

```swift
let results = try client.browse(
    nodeValues: [.numeric(nameSpace: 0, identifier: 2253)]
).wait()
for result in results {
    result.references.forEach { ref in
        print("\(ref.displayName.text): \(ref.nodeValue)")
    }
}
```

Chiamato senza argomenti, `browse()` parte dal nodo radice.

### Read

```swift
let reads = [
    ReadValue(nodeValue: .numeric(nameSpace: 0, identifier: 2258))
]
let values = try client.read(nodes: reads).wait()
values.forEach { value in
    print("\(value.statusCode): \(value.variant.value)")
}
```

Nota: ogni nodo richiesto produce un risultato, anche in caso di errore per singolo nodo. Lo status code e' riportato in `value.statusCode` (vedi "Note su errori di Read").

### Write

```swift
let writes: [WriteValue] = [
    WriteValue(
        nodeValue: .string(nameSpace: 5, identifier: "MyLevel"),
        value: DataValue(variant: Variant(value: Double(21.0)))
    )
]
let statuses = try client.write(nodes: writes).wait()
print(statuses)
```

E' disponibile anche l'overload `write(nodeValues:values:)` che costruisce i `WriteValue` automaticamente.

### Subscription + MonitoredItems

```swift
let subscription = Subscription(
    requestedPublishingInterval: 1000,
    requestedLifetimeCount: 1000,
    requestedMaxKeepAliveCount: 12,
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
        itemToMonitor: ReadValue(nodeValue: .string(nameSpace: 3, identifier: "Counter")),
        requestedParameters: MonitoringParameters(clientHandle: 1, samplingInterval: 250),
        monitoringMode: .reporting
    ),
    MonitoredItemCreateRequest(
        itemToMonitor: ReadValue(nodeValue: .numeric(nameSpace: 3, identifier: 1002)),
        requestedParameters: MonitoringParameters(clientHandle: 2, samplingInterval: 250)
    )
]

let results = try client.createMonitoredItems(subscriptionId: subscriptionId, itemsToCreate: itemsToCreate).wait()
results.forEach { result in
    print("createMonitoredItem: \(result.monitoredItemId) = \(result.statusCode)")
}
```

`monitoringMode` ammette `.disabled`, `.sampling` e `.reporting` (default `.reporting`).

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

let nodes = [ReadValue(nodeValue: .numeric(nameSpace: 0, identifier: 2258))]
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
    privateKey: "/path/to/client-key.pem"
)
```

## Note su errori di Read

- La read **non** fallisce se il server risponde con `BadNodeIdUnknown` o simili: tutti i risultati vengono restituiti e lo status code per singolo nodo e' disponibile in `value.statusCode`.
- Per distinguere i valori validi verificare `value.statusCode == .UA_STATUSCODE_GOOD`.
- In console viene stampato `Warning: ReadResponse status code: <StatusCode>` per ogni risultato con status non GOOD.
- Gli errori di trasporto/sessione (timeout, canale chiuso) falliscono invece il future o il `try await`.

## Test

```bash
swift test
```

Gli integration test richiedono un server OPC UA raggiungibile. Per la sola suite offline:

```bash
swift test --skip ZenOPCUAIntegrationTests
```

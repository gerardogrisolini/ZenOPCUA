# AGENTS.md

Swift Package (SwiftPM) providing `ZenOPCUA`, an OPC UA client library built on SwiftNIO. The repo root is the package root; there is no app target or Xcode project (SwiftUI is not used anywhere in the package).

## Build & test

- Build with `swift build`; run tests with `swift test` (also documented in `README.md`). Swift tools 6.3, Swift 6 language mode.
- Both targets enable `NonisolatedNonsendingByDefault` (`Package.swift`); strict concurrency checking is fully enforced by Swift 6 language mode. New code must compile under strict concurrency.
- Supported platforms: macOS 10.15, iOS 13, watchOS 6.
- `Tests/ZenOPCUATests/ZenOPCUAIntegrationTests.swift` requires a live OPC UA server (`opc.tcp://Gerardos-MacBook-Pro.local:53530/OPCUA/SimulationServer`) and hard-codes certificate paths under `/Users/gerardo/Projects/ZenOPCUA/certificates/`, which do not match this checkout (`/Users/gerardo/Projects/biesse/ZenOPCUA`). These tests are not skipped automatically; run `swift test --skip ZenOPCUAIntegrationTests` to validate offline (unit tests in the other files need no server).

## Layout

- `Sources/ZenOPCUA/ZenOPCUA.swift` — main `ZenOPCUA` client class and public API entry point (connect/disconnect, browse, read/write, subscriptions; both EventLoopFuture and async/await variants).
- `Sources/ZenOPCUA/Transport/` — NIO channel handler plus OPC UA frame encoder/decoder/codec.
- `Sources/ZenOPCUA/Core/` — `OPCUAHandler` and connection state.
- `Sources/ZenOPCUA/Security/` — security policies and RSA crypto (swift-crypto, swift-certificates/X509).
- `Sources/ZenOPCUA/Models/` — OPC UA wire types in `Requests/`, `Responses/`, `Common/` (node IDs, DataValue, chunk types, status codes).
- `Sources/ZenOPCUA/Actors/` — Swift actors for connection coordination, publishing, and async streams.
- `Sources/ZenOPCUA/Extensions/` — byte encoding/decoding extensions for primitives.
- `Tests/ZenOPCUATests/` — offline unit tests plus the integration suite above.

## Gotchas

- The node identifier type is `NodeValue` (`Sources/ZenOPCUA/Models/Common/Nodes.swift`). `README.md` examples still use `NodeIdNumeric`/`NodeIdString`, which no longer exist — verify API usage against `Sources/` rather than the README.
- Public `Subscription` property names contain legacy misspellings (`requestedPubliscingInterval`, `requesteMaxKeepAliveCount`). They are public API used by tests and README; do not rename casually.
- `certificates/` holds local PEM material for secure endpoints; `certificates/README.md` documents the openssl commands, including the `openssl rsa` conversion that produces the `-rsa` key variant used by tests.

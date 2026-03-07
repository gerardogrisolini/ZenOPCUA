import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ZenOPCUAPrimitiveExtensionsUnitTests.allTests),
        testCase(ZenOPCUANodeValueUnitTests.allTests),
        testCase(ZenOPCUADataValueAndActorsUnitTests.allTests),
        testCase(ZenOPCUAUnitTests.allTests),
        testCase(ZenOPCUAIntegrationTests.allTests),
    ]
}
#endif

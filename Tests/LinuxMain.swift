import XCTest

import ZenOPCUATests

var tests = [XCTestCaseEntry]()
tests += ZenOPCUAPrimitiveExtensionsUnitTests.allTests()
tests += ZenOPCUANodeValueUnitTests.allTests()
tests += ZenOPCUADataValueAndActorsUnitTests.allTests()
tests += ZenOPCUAUnitTests.allTests()
tests += ZenOPCUAIntegrationTests.allTests()
XCTMain(tests)

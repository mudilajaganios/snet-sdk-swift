import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(snet_sdk_swiftTests.allTests),
    ]
}
#endif

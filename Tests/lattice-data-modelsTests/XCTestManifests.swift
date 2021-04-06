import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(lattice_data_modelsTests.allTests),
    ]
}
#endif

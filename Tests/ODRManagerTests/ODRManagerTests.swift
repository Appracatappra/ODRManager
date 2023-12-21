import XCTest
@testable import ODRManager

final class ODRManagerTests: XCTestCase {
    func testODR() throws {
        let control:ODRManager? = ODRManager()
        
        XCTAssert(control != nil)
    }
}

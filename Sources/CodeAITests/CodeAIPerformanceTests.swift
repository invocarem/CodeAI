@testable import CodeAI
import XCTest
import XCTVapor

final class CodeAIPerformanceTests: XCTestCase {
    
    func testHealthEndpointPerformance() throws {
        measure {
            do {
                let app = try Application(.testing)
                defer { app.shutdown() }
                try configure(app)
                
                try app.test(.GET, "health") { res in
                    XCTAssertEqual(res.status, .ok)
                }
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testModelsEndpointPerformance() throws {
        measure {
            do {
                let app = try Application(.testing)
                defer { app.shutdown() }
                try configure(app)
                
                try app.test(.GET, "v1/models") { res in
                    XCTAssertEqual(res.status, .ok)
                }
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}
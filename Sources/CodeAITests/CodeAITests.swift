@testable import CodeAI
import XCTest
import XCTVapor

final class CodeAITests: XCTestCase
{
  func testHealthEndpoint() async throws
  {
    let app = Application(.testing)
    defer { app.shutdown() }
    try configure(app)

    try app.test(.GET, "health")
    { res in
      XCTAssertEqual(res.status, .ok)
      let health = try res.content.decode(HealthResponse.self)
      XCTAssertTrue(health.ok)
    }
  }

  func testModelsEndpoint() async throws
  {
    let app = Application(.testing)
    defer { app.shutdown() }
    try configure(app)

    try app.test(.GET, "v1/models")
    { res in
      XCTAssertEqual(res.status, .ok)
      let models = try res.content.decode(ModelsResponse.self)
      XCTAssertFalse(models.data.isEmpty)
    }
  }

  

}


extension XCTestCase {
    func XCTAssertContains(_ string: String, _ substring: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(string.contains(substring), "Expected '\(string)' to contain '\(substring)'", file: file, line: line)
    }
}
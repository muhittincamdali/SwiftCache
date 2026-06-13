import XCTest
@testable import SwiftCache

final class SwiftCacheTests: XCTestCase {
    func testLRUCache() async {
        let cache = LRUCache<String, String>(capacity: 2)
        await cache.set("value", forKey: "key")
        let value = await cache.get(forKey: "key")
        XCTAssertEqual(value, "value")
    }
}

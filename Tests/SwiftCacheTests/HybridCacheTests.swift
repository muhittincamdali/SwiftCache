// HybridCacheTests.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import XCTest
@testable import SwiftCache

/// Tests for HybridCache implementation.
final class HybridCacheTests: XCTestCase {
    
    // MARK: - Properties
    
    var cache: HybridCache<String, TestUser>!
    var testDirectory: URL!
    
    /// Test user structure.
    struct TestUser: Codable, Equatable, Sendable {
        let id: Int
        let name: String
        let email: String
        
        static func random() -> TestUser {
            TestUser(
                id: Int.random(in: 1...1000),
                name: "User \(Int.random(in: 1...100))",
                email: "user\(Int.random(in: 1...100))@example.com"
            )
        }
    }
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HybridCacheTests_\(UUID().uuidString)")
        
        cache = try HybridCache<String, TestUser>(
            name: "hybrid_test",
            configuration: .default,
            directory: testDirectory
        )
    }
    
    override func tearDown() async throws {
        await cache.removeAll()
        try? FileManager.default.removeItem(at: testDirectory)
        cache = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Operations Tests
    
    func testSetAndGet() async throws {
        // Given
        let key = "user_1"
        let user = TestUser.random()
        
        // When
        await cache.set(key, value: user)
        let retrieved = await cache.get(key)
        
        // Then
        XCTAssertEqual(retrieved, user)
    }
    
    func testGetNonExistentKey() async throws {
        // When
        let result = await cache.get("nonexistent")
        
        // Then
        XCTAssertNil(result)
    }
    
    func testRemove() async throws {
        // Given
        let user = TestUser.random()
        await cache.set("user", value: user)
        
        // When
        await cache.remove("user")
        let result = await cache.get("user")
        
        // Then
        XCTAssertNil(result)
    }
    
    func testRemoveAll() async throws {
        // Given
        await cache.set("user1", value: TestUser.random())
        await cache.set("user2", value: TestUser.random())
        
        // When
        await cache.removeAll()
        
        // Then
        let result1 = await cache.get("user1")
        let result2 = await cache.get("user2")
        
        XCTAssertNil(result1)
        XCTAssertNil(result2)
    }
    
    func testContains() async throws {
        // Given
        await cache.set("exists", value: TestUser.random())
        
        // Then
        let containsExisting = await cache.contains("exists")
        let containsNonExisting = await cache.contains("notexists")
        
        XCTAssertTrue(containsExisting)
        XCTAssertFalse(containsNonExisting)
    }
    
    // MARK: - Layer Tests
    
    func testGetWithSource() async throws {
        // Given
        let user = TestUser.random()
        await cache.set("user", value: user)
        
        // First access should be memory hit
        let first = await cache.getWithSource("user")
        XCTAssertEqual(first?.source, .memory)
        
        // Clear memory
        await cache.clearMemory()
        
        // Next access should be disk hit
        let second = await cache.getWithSource("user")
        XCTAssertEqual(second?.source, .disk)
    }
    
    func testGetFromMemoryOnly() async throws {
        // Given
        let user = TestUser.random()
        await cache.set("user", value: user)
        
        // When
        let memoryResult = await cache.getFromMemory("user")
        
        // Then
        XCTAssertEqual(memoryResult, user)
    }
    
    func testGetFromDiskOnly() async throws {
        // Given
        let user = TestUser.random()
        await cache.set("user", value: user)
        
        // When
        let diskResult = await cache.getFromDisk("user")
        
        // Then
        XCTAssertEqual(diskResult, user)
    }
    
    func testClearMemoryOnly() async throws {
        // Given
        let user = TestUser.random()
        await cache.set("user", value: user)
        
        // When
        await cache.clearMemory()
        
        // Then - memory empty but disk has data
        let memoryResult = await cache.getFromMemory("user")
        let diskResult = await cache.getFromDisk("user")
        
        XCTAssertNil(memoryResult)
        XCTAssertEqual(diskResult, user)
    }
    
    func testClearDiskOnly() async throws {
        // Given
        let user = TestUser.random()
        await cache.set("user", value: user)
        
        // When
        await cache.clearDisk()
        
        // Then - memory has data but disk empty
        let memoryResult = await cache.getFromMemory("user")
        let diskResult = await cache.getFromDisk("user")
        
        XCTAssertEqual(memoryResult, user)
        XCTAssertNil(diskResult)
    }
    
    // MARK: - Promotion Tests
    
    func testDiskHitPromotesToMemory() async throws {
        // Given
        let config = HybridCache<String, TestUser>.Configuration(
            promoteOnDiskHit: true
        )
        let promotingCache = try HybridCache<String, TestUser>(
            name: "promoting_test",
            configuration: config,
            directory: testDirectory
        )
        
        let user = TestUser.random()
        await promotingCache.set("user", value: user)
        await promotingCache.clearMemory()
        
        // When - disk hit should promote
        _ = await promotingCache.get("user")
        
        // Then - should now be in memory
        let memoryResult = await promotingCache.getFromMemory("user")
        XCTAssertEqual(memoryResult, user)
    }
    
    // MARK: - Options Tests
    
    func testSkipMemoryOption() async throws {
        // Given
        let user = TestUser.random()
        
        // When - skip memory
        await cache.set("user", value: user, options: .skipMemory)
        
        // Then - not in memory
        let memoryResult = await cache.getFromMemory("user")
        let diskResult = await cache.getFromDisk("user")
        
        XCTAssertNil(memoryResult)
        XCTAssertEqual(diskResult, user)
    }
    
    func testSkipDiskOption() async throws {
        // Given
        let user = TestUser.random()
        
        // When - skip disk
        await cache.set("user", value: user, options: .skipDisk)
        
        // Then - not on disk
        let memoryResult = await cache.getFromMemory("user")
        let diskResult = await cache.getFromDisk("user")
        
        XCTAssertEqual(memoryResult, user)
        XCTAssertNil(diskResult)
    }
    
    // MARK: - Statistics Tests
    
    func testStatistics() async throws {
        // Given
        await cache.set("user", value: TestUser.random())
        
        // When
        _ = await cache.get("user")       // Memory hit
        await cache.clearMemory()
        _ = await cache.get("user")       // Disk hit
        _ = await cache.get("missing")    // Miss
        
        // Then
        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.memoryHits, 1)
        XCTAssertEqual(stats.diskHits, 1)
        XCTAssertEqual(stats.misses, 1)
    }
    
    func testHitRate() async throws {
        // Given
        await cache.set("user", value: TestUser.random())
        
        // 2 hits, 1 miss = 66.67%
        _ = await cache.get("user")
        _ = await cache.get("user")
        _ = await cache.get("missing")
        
        // Then
        let stats = await cache.getStatistics()
        XCTAssertGreaterThan(stats.hitRate, 60)
        XCTAssertLessThan(stats.hitRate, 70)
    }
    
    // MARK: - Preload Tests
    
    func testPreload() async throws {
        // Given
        let users = (1...5).map { _ in TestUser.random() }
        for (i, user) in users.enumerated() {
            await cache.set("user_\(i)", value: user)
        }
        await cache.clearMemory()
        
        // When - preload specific keys
        let keysToPreload = ["user_0", "user_2", "user_4"]
        await cache.preload(keys: keysToPreload)
        
        // Then - preloaded keys should be in memory
        for key in keysToPreload {
            let memoryResult = await cache.getFromMemory(key)
            XCTAssertNotNil(memoryResult)
        }
        
        // Non-preloaded should not be in memory
        let notPreloaded = await cache.getFromMemory("user_1")
        XCTAssertNil(notPreloaded)
    }
    
    // MARK: - Expiration Tests
    
    func testRemoveExpired() async throws {
        // Given
        await cache.set("expires", value: TestUser.random(), expiration: .seconds(0.05))
        await cache.set("stays", value: TestUser.random(), expiration: .never)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let removed = await cache.removeExpired()
        
        // Then
        XCTAssertGreaterThan(removed, 0)
    }
    
    // MARK: - Flush Tests
    
    func testFlush() async throws {
        // Given
        await cache.setDeferred("user1", value: TestUser.random())
        await cache.setDeferred("user2", value: TestUser.random())
        
        // When
        await cache.flush()
        
        // Then - should be on disk
        let disk1 = await cache.getFromDisk("user1")
        let disk2 = await cache.getFromDisk("user2")
        
        XCTAssertNotNil(disk1)
        XCTAssertNotNil(disk2)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAccess() async throws {
        // Given
        let iterations = 50
        
        // When - concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    await self.cache.set("key_\(i)", value: TestUser.random())
                }
                group.addTask {
                    _ = await self.cache.get("key_\(i % 10)")
                }
            }
        }
        
        // Then - should complete without crashes
        let result = await cache.get("key_0")
        XCTAssertNotNil(result)
    }
}

// DiskCacheTests.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import XCTest
@testable import SwiftCache

/// Tests for DiskCache implementation.
final class DiskCacheTests: XCTestCase {
    
    // MARK: - Properties
    
    var cache: DiskCache<String, TestData>!
    var testDirectory: URL!
    
    /// Codable test data structure.
    struct TestData: Codable, Equatable, Sendable {
        let id: Int
        let content: String
        let timestamp: Date
        
        static func random() -> TestData {
            TestData(
                id: Int.random(in: 1...1000),
                content: UUID().uuidString,
                timestamp: Date()
            )
        }
    }
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftCacheTests_\(UUID().uuidString)")
        
        cache = try DiskCache<String, TestData>(
            name: "test_cache",
            directory: testDirectory,
            maxSize: 10 * 1024 * 1024
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
        let key = "test_key"
        let value = TestData.random()
        
        // When
        try await cache.set(key, value: value)
        let retrieved = await cache.get(key)
        
        // Then
        XCTAssertEqual(retrieved?.id, value.id)
        XCTAssertEqual(retrieved?.content, value.content)
    }
    
    func testGetNonExistentKey() async throws {
        // When
        let result = await cache.get("nonexistent")
        
        // Then
        XCTAssertNil(result)
    }
    
    func testRemove() async throws {
        // Given
        let value = TestData.random()
        try await cache.set("key", value: value)
        
        // When
        await cache.remove("key")
        let result = await cache.get("key")
        
        // Then
        XCTAssertNil(result)
    }
    
    func testRemoveAll() async throws {
        // Given
        try await cache.set("key1", value: TestData.random())
        try await cache.set("key2", value: TestData.random())
        try await cache.set("key3", value: TestData.random())
        
        // When
        await cache.removeAll()
        
        // Then
        let count = await cache.count
        XCTAssertEqual(count, 0)
    }
    
    func testContains() async throws {
        // Given
        try await cache.set("exists", value: TestData.random())
        
        // Then
        let containsExisting = await cache.contains("exists")
        let containsNonExisting = await cache.contains("notexists")
        
        XCTAssertTrue(containsExisting)
        XCTAssertFalse(containsNonExisting)
    }
    
    func testCount() async throws {
        // Given
        try await cache.set("key1", value: TestData.random())
        try await cache.set("key2", value: TestData.random())
        
        // When
        let count = await cache.count
        
        // Then
        XCTAssertEqual(count, 2)
    }
    
    // MARK: - Persistence Tests
    
    func testDataPersistsAcrossInstances() async throws {
        // Given
        let value = TestData.random()
        try await cache.set("persistent_key", value: value)
        
        // When - create new cache instance
        let newCache = try DiskCache<String, TestData>(
            name: "test_cache",
            directory: testDirectory
        )
        
        // Then
        let retrieved = await newCache.get("persistent_key")
        XCTAssertEqual(retrieved?.id, value.id)
    }
    
    // MARK: - Expiration Tests
    
    func testExpirationSeconds() async throws {
        // Given
        try await cache.set("key", value: TestData.random(), expiration: .seconds(0.1))
        
        // Initially exists
        var result = await cache.get("key")
        XCTAssertNotNil(result)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then expired
        result = await cache.get("key")
        XCTAssertNil(result)
    }
    
    func testRemoveExpired() async throws {
        // Given
        try await cache.set("expires", value: TestData.random(), expiration: .seconds(0.05))
        try await cache.set("stays", value: TestData.random(), expiration: .never)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let removed = await cache.removeExpired()
        
        // Then
        XCTAssertEqual(removed, 1)
        
        let expiresResult = await cache.get("expires")
        let staysResult = await cache.get("stays")
        
        XCTAssertNil(expiresResult)
        XCTAssertNotNil(staysResult)
    }
    
    // MARK: - Size Management Tests
    
    func testTotalSize() async throws {
        // Given
        try await cache.set("key1", value: TestData.random())
        try await cache.set("key2", value: TestData.random())
        
        // When
        let size = await cache.totalSize
        
        // Then
        XCTAssertGreaterThan(size, 0)
    }
    
    func testSizeEviction() async throws {
        // Given - small max size
        let smallCache = try DiskCache<String, TestData>(
            name: "small_cache",
            directory: testDirectory,
            maxSize: 500  // Very small
        )
        
        // When - add items that exceed size
        for i in 0..<10 {
            try await smallCache.set("key_\(i)", value: TestData.random())
        }
        
        // Then - should have evicted some items
        let count = await smallCache.count
        XCTAssertLessThan(count, 10)
    }
    
    // MARK: - Keys Tests
    
    func testKeys() async throws {
        // Given
        try await cache.set("key1", value: TestData.random())
        try await cache.set("key2", value: TestData.random())
        
        // When
        let keys = await cache.keys
        
        // Then
        XCTAssertEqual(Set(keys), Set(["key1", "key2"]))
    }
    
    // MARK: - Statistics Tests
    
    func testStatistics() async throws {
        // Given
        try await cache.set("key", value: TestData.random())
        
        // When
        _ = await cache.get("key")       // Hit
        _ = await cache.get("missing")   // Miss
        
        // Then
        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
    }
    
    // MARK: - Integrity Tests
    
    func testVerifyIntegrity() async throws {
        // Given
        try await cache.set("key1", value: TestData.random())
        try await cache.set("key2", value: TestData.random())
        
        // When
        let corrupted = await cache.verifyIntegrity()
        
        // Then
        XCTAssertEqual(corrupted, 0)
    }
    
    // MARK: - Update Tests
    
    func testUpdateExistingKey() async throws {
        // Given
        let original = TestData(id: 1, content: "original", timestamp: Date())
        let updated = TestData(id: 1, content: "updated", timestamp: Date())
        
        try await cache.set("key", value: original)
        
        // When
        try await cache.set("key", value: updated)
        let result = await cache.get("key")
        
        // Then
        XCTAssertEqual(result?.content, "updated")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAccess() async throws {
        // Given
        let iterations = 50
        
        // When - concurrent writes
        await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    try await self.cache.set("key_\(i)", value: TestData.random())
                }
            }
        }
        
        // Then - all writes succeeded
        let count = await cache.count
        XCTAssertEqual(count, iterations)
    }
    
    // MARK: - String Value Tests
    
    func testWithStringValues() async throws {
        // Given
        let stringCache = try DiskCache<String, String>(
            name: "string_cache",
            directory: testDirectory
        )
        
        // When
        try await stringCache.set("hello", value: "world")
        let result = await stringCache.get("hello")
        
        // Then
        XCTAssertEqual(result, "world")
    }
    
    // MARK: - Large Data Tests
    
    func testLargeData() async throws {
        // Given
        struct LargeData: Codable, Sendable {
            let data: [Int]
        }
        
        let largeCache = try DiskCache<String, LargeData>(
            name: "large_cache",
            directory: testDirectory
        )
        
        let large = LargeData(data: Array(0..<10000))
        
        // When
        try await largeCache.set("large", value: large)
        let result = await largeCache.get("large")
        
        // Then
        XCTAssertEqual(result?.data.count, 10000)
    }
    
    // MARK: - File System Tests
    
    func testComputeDiskUsage() async throws {
        // Given
        try await cache.set("key1", value: TestData.random())
        try await cache.set("key2", value: TestData.random())
        
        // When
        let usage = await cache.computeDiskUsage()
        
        // Then
        XCTAssertGreaterThan(usage, 0)
    }
}

// MemoryCacheTests.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import XCTest
@testable import SwiftCache

/// Tests for MemoryCache implementation.
final class MemoryCacheTests: XCTestCase {
    
    // MARK: - Properties
    
    var cache: MemoryCache<String, String>!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        cache = MemoryCache<String, String>(configuration: .default)
    }
    
    override func tearDown() async throws {
        await cache.removeAll()
        cache = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Operations Tests
    
    func testSetAndGet() async throws {
        // Given
        let key = "test_key"
        let value = "test_value"
        
        // When
        await cache.set(key, value: value)
        let retrieved = await cache.get(key)
        
        // Then
        XCTAssertEqual(retrieved, value)
    }
    
    func testGetNonExistentKey() async throws {
        // When
        let result = await cache.get("nonexistent")
        
        // Then
        XCTAssertNil(result)
    }
    
    func testRemove() async throws {
        // Given
        await cache.set("key", value: "value")
        
        // When
        await cache.remove("key")
        let result = await cache.get("key")
        
        // Then
        XCTAssertNil(result)
    }
    
    func testRemoveAll() async throws {
        // Given
        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        await cache.set("key3", value: "value3")
        
        // When
        await cache.removeAll()
        
        // Then
        let count = await cache.count
        XCTAssertEqual(count, 0)
    }
    
    func testContains() async throws {
        // Given
        await cache.set("exists", value: "yes")
        
        // Then
        let containsExisting = await cache.contains("exists")
        let containsNonExisting = await cache.contains("notexists")
        
        XCTAssertTrue(containsExisting)
        XCTAssertFalse(containsNonExisting)
    }
    
    func testCount() async throws {
        // Given
        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        
        // When
        let count = await cache.count
        
        // Then
        XCTAssertEqual(count, 2)
    }
    
    func testIsEmpty() async throws {
        // Initially empty
        var isEmpty = await cache.isEmpty
        XCTAssertTrue(isEmpty)
        
        // After adding
        await cache.set("key", value: "value")
        isEmpty = await cache.isEmpty
        XCTAssertFalse(isEmpty)
    }
    
    // MARK: - Update Tests
    
    func testUpdateExistingKey() async throws {
        // Given
        await cache.set("key", value: "original")
        
        // When
        await cache.set("key", value: "updated")
        let result = await cache.get("key")
        
        // Then
        XCTAssertEqual(result, "updated")
    }
    
    // MARK: - Expiration Tests
    
    func testExpirationSeconds() async throws {
        // Given
        await cache.set("key", value: "value", expiration: .seconds(0.1))
        
        // Initially exists
        var result = await cache.get("key")
        XCTAssertNotNil(result)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then expired
        result = await cache.get("key")
        XCTAssertNil(result)
    }
    
    func testNeverExpires() async throws {
        // Given
        await cache.set("key", value: "value", expiration: .never)
        
        // When (no delay needed, just verify it doesn't expire immediately)
        let result = await cache.get("key")
        
        // Then
        XCTAssertNotNil(result)
    }
    
    func testRemoveExpired() async throws {
        // Given
        await cache.set("expires", value: "soon", expiration: .seconds(0.05))
        await cache.set("stays", value: "forever", expiration: .never)
        
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
    
    // MARK: - Statistics Tests
    
    func testStatisticsHitMiss() async throws {
        // Given
        let config = CacheConfiguration(trackStatistics: true)
        let statsCache = MemoryCache<String, String>(configuration: config)
        
        await statsCache.set("key", value: "value")
        
        // When
        _ = await statsCache.get("key")       // Hit
        _ = await statsCache.get("missing")   // Miss
        _ = await statsCache.get("key")       // Hit
        
        // Then
        let stats = await statsCache.getStatistics()
        XCTAssertEqual(stats.hitCount, 2)
        XCTAssertEqual(stats.missCount, 1)
    }
    
    func testHitRate() async throws {
        // Given
        let config = CacheConfiguration(trackStatistics: true)
        let statsCache = MemoryCache<String, String>(configuration: config)
        
        await statsCache.set("key", value: "value")
        
        // 3 hits, 1 miss = 75% hit rate
        _ = await statsCache.get("key")
        _ = await statsCache.get("key")
        _ = await statsCache.get("key")
        _ = await statsCache.get("missing")
        
        // Then
        let stats = await statsCache.getStatistics()
        XCTAssertEqual(stats.hitRate, 75.0)
    }
    
    // MARK: - Keys and Values Tests
    
    func testKeys() async throws {
        // Given
        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        
        // When
        let keys = await cache.keys
        
        // Then
        XCTAssertEqual(Set(keys), Set(["key1", "key2"]))
    }
    
    func testValues() async throws {
        // Given
        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        
        // When
        let values = await cache.values
        
        // Then
        XCTAssertEqual(Set(values), Set(["value1", "value2"]))
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAccess() async throws {
        // Given
        let iterations = 100
        
        // When - concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    await self.cache.set("key_\(i)", value: "value_\(i)")
                }
            }
        }
        
        // Then
        let count = await cache.count
        XCTAssertEqual(count, iterations)
        
        // Concurrent reads
        await withTaskGroup(of: String?.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    await self.cache.get("key_\(i)")
                }
            }
            
            var results: [String?] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.compactMap { $0 }.count, iterations)
        }
    }
    
    func testConcurrentReadWrite() async throws {
        // Given
        await cache.set("shared", value: "initial")
        
        // When - concurrent read/write
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 0..<50 {
                group.addTask {
                    await self.cache.set("shared", value: "value_\(i)")
                }
            }
            
            // Readers
            for _ in 0..<50 {
                group.addTask {
                    _ = await self.cache.get("shared")
                }
            }
        }
        
        // Then - should complete without crashes
        let result = await cache.get("shared")
        XCTAssertNotNil(result)
    }
    
    // MARK: - Metadata Tests
    
    func testGetWithMetadata() async throws {
        // Given
        await cache.set("key", value: "value")
        
        // When
        let result = await cache.getWithMetadata("key")
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, "value")
        XCTAssertEqual(result?.1.accessCount, 1)
    }
    
    // MARK: - Update Expiration Tests
    
    func testUpdateExpiration() async throws {
        // Given
        await cache.set("key", value: "value", expiration: .seconds(10))
        
        // When
        let updated = await cache.updateExpiration("key", expiration: .seconds(0.05))
        
        // Then
        XCTAssertTrue(updated)
        
        // Wait for new expiration
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let result = await cache.get("key")
        XCTAssertNil(result)
    }
    
    // MARK: - Different Value Types Tests
    
    func testWithDataValues() async throws {
        // Given
        let dataCache = MemoryCache<String, Data>()
        let testData = "Hello World".data(using: .utf8)!
        
        // When
        await dataCache.set("data_key", value: testData)
        let result = await dataCache.get("data_key")
        
        // Then
        XCTAssertEqual(result, testData)
    }
    
    func testWithCodableValues() async throws {
        // Given
        struct User: Codable, Equatable, Sendable {
            let id: Int
            let name: String
        }
        
        let userCache = MemoryCache<String, User>()
        let user = User(id: 1, name: "Test User")
        
        // When
        await userCache.set("user_1", value: user)
        let result = await userCache.get("user_1")
        
        // Then
        XCTAssertEqual(result, user)
    }
    
    func testWithIntegerKeys() async throws {
        // Given
        let intCache = MemoryCache<Int, String>()
        
        // When
        await intCache.set(1, value: "one")
        await intCache.set(2, value: "two")
        
        // Then
        let one = await intCache.get(1)
        let two = await intCache.get(2)
        
        XCTAssertEqual(one, "one")
        XCTAssertEqual(two, "two")
    }
}

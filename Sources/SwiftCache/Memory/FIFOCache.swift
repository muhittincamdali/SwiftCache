// FIFOCache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - FIFO Cache

/// A First In First Out (FIFO) cache implementation.
///
/// `FIFOCache` evicts items in the order they were added, regardless
/// of access patterns. This provides predictable behavior and is useful
/// when insertion order matters more than access frequency.
///
/// ## Overview
/// Items are evicted based on when they were added, not when they
/// were last accessed.
///
/// ```swift
/// let cache = FIFOCache<String, Data>(capacity: 100)
///
/// await cache.set("first", value: data1)
/// await cache.set("second", value: data2)
///
/// // Even if "first" is accessed frequently, it will be
/// // evicted before "second" when the cache is full
/// ```
///
/// ## Use Cases
/// - Time-series data where older data is less relevant
/// - Request queues
/// - Streaming data buffers
///
/// ## Performance
/// - Get: O(1)
/// - Set: O(1) amortized
/// - Remove: O(n) worst case
public actor FIFOCache<Key: Hashable & Sendable, Value: Sendable>: CacheProtocol {
    
    // MARK: - Entry
    
    private struct Entry: Sendable {
        let value: Value
        let insertionTime: Date
        var expiration: Date?
        
        var isExpired: Bool {
            guard let exp = expiration else { return false }
            return Date() > exp
        }
    }
    
    // MARK: - Properties
    
    /// Maximum number of items.
    public let capacity: Int
    
    /// Storage dictionary.
    private var storage: [Key: Entry] = [:]
    
    /// Insertion order queue.
    private var queue: [Key] = []
    
    /// Cache statistics.
    private var stats = CacheStatistics()
    
    /// Whether to track statistics.
    private let trackStatistics: Bool
    
    /// Default expiration.
    private let defaultExpiration: CacheExpiration
    
    // MARK: - Initialization
    
    /// Creates a new FIFO cache.
    ///
    /// - Parameters:
    ///   - capacity: Maximum number of items.
    ///   - trackStatistics: Whether to track statistics.
    ///   - defaultExpiration: Default expiration for entries.
    public init(
        capacity: Int,
        trackStatistics: Bool = true,
        defaultExpiration: CacheExpiration = .never
    ) {
        precondition(capacity > 0, "Capacity must be at least 1")
        self.capacity = capacity
        self.trackStatistics = trackStatistics
        self.defaultExpiration = defaultExpiration
    }
    
    // MARK: - CacheProtocol Implementation
    
    /// Retrieves a value from the cache.
    ///
    /// Note: Unlike LRU, accessing a value does not affect eviction order.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil` if not found or expired.
    public func get(_ key: Key) async -> Value? {
        guard let entry = storage[key] else {
            if trackStatistics { stats.missCount += 1 }
            return nil
        }
        
        if entry.isExpired {
            await remove(key)
            if trackStatistics {
                stats.missCount += 1
                stats.expirationCount += 1
            }
            return nil
        }
        
        if trackStatistics { stats.hitCount += 1 }
        return entry.value
    }
    
    /// Stores a value in the cache.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - expiration: Optional expiration policy.
    public func set(_ key: Key, value: Value, expiration: CacheExpiration? = nil) async {
        let exp = expiration ?? defaultExpiration
        
        // Check if key already exists
        if storage[key] != nil {
            // Update existing - don't change queue position
            storage[key] = Entry(
                value: value,
                insertionTime: Date(),
                expiration: exp.expirationDate
            )
            return
        }
        
        // Evict oldest if at capacity
        while storage.count >= capacity {
            evictOldest()
        }
        
        // Add new entry
        let entry = Entry(
            value: value,
            insertionTime: Date(),
            expiration: exp.expirationDate
        )
        storage[key] = entry
        queue.append(key)
        
        if trackStatistics { stats.itemCount = storage.count }
    }
    
    /// Removes a value from the cache.
    ///
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) async {
        storage.removeValue(forKey: key)
        queue.removeAll { $0 == key }
        if trackStatistics { stats.itemCount = storage.count }
    }
    
    /// Removes all values from the cache.
    public func removeAll() async {
        storage.removeAll()
        queue.removeAll()
        if trackStatistics { stats.itemCount = 0 }
    }
    
    /// Checks if a key exists and is not expired.
    public func contains(_ key: Key) async -> Bool {
        guard let entry = storage[key] else { return false }
        return !entry.isExpired
    }
    
    /// Returns the number of items in the cache.
    public var count: Int {
        storage.count
    }
    
    // MARK: - Extended Operations
    
    /// Returns the oldest item in the cache.
    public var oldest: (key: Key, value: Value)? {
        guard let key = queue.first, let entry = storage[key] else { return nil }
        return (key, entry.value)
    }
    
    /// Returns the newest item in the cache.
    public var newest: (key: Key, value: Value)? {
        guard let key = queue.last, let entry = storage[key] else { return nil }
        return (key, entry.value)
    }
    
    /// Returns keys in insertion order (oldest first).
    public var keysInOrder: [Key] {
        queue
    }
    
    /// Removes all expired entries.
    @discardableResult
    public func removeExpired() async -> Int {
        var removed = 0
        var keysToRemove: [Key] = []
        
        for (key, entry) in storage where entry.isExpired {
            keysToRemove.append(key)
        }
        
        for key in keysToRemove {
            storage.removeValue(forKey: key)
            queue.removeAll { $0 == key }
            removed += 1
        }
        
        if trackStatistics {
            stats.expirationCount += removed
            stats.itemCount = storage.count
        }
        
        return removed
    }
    
    /// Returns cache statistics.
    public func getStatistics() -> CacheStatistics {
        stats
    }
    
    /// Resets cache statistics.
    public func resetStatistics() {
        stats.reset()
    }
    
    /// Returns the insertion time of an entry.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: The insertion time, or `nil` if not found.
    public func insertionTime(for key: Key) -> Date? {
        storage[key]?.insertionTime
    }
    
    /// Returns entries older than the specified date.
    ///
    /// - Parameter date: The cutoff date.
    /// - Returns: Array of keys older than the date.
    public func keysOlderThan(_ date: Date) -> [Key] {
        storage.filter { $0.value.insertionTime < date }.map { $0.key }
    }
    
    /// Removes entries older than the specified date.
    ///
    /// - Parameter date: The cutoff date.
    /// - Returns: Number of entries removed.
    @discardableResult
    public func removeOlderThan(_ date: Date) async -> Int {
        let keysToRemove = keysOlderThan(date)
        
        for key in keysToRemove {
            storage.removeValue(forKey: key)
            queue.removeAll { $0 == key }
        }
        
        if trackStatistics { stats.itemCount = storage.count }
        
        return keysToRemove.count
    }
    
    // MARK: - Private Methods
    
    /// Evicts the oldest item in the queue.
    private func evictOldest() {
        guard !queue.isEmpty else { return }
        
        let key = queue.removeFirst()
        storage.removeValue(forKey: key)
        
        if trackStatistics {
            stats.evictionCount += 1
            stats.itemCount = storage.count
        }
    }
}

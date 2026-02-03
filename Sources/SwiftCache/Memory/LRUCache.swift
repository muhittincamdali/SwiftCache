// LRUCache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - LRU Cache

/// A Least Recently Used (LRU) cache implementation.
///
/// `LRUCache` maintains items in order of access, evicting the least
/// recently accessed items when the cache reaches capacity. This is
/// ideal for scenarios where recent access patterns predict future access.
///
/// ## Overview
/// The LRU cache automatically evicts the least recently used items
/// when it reaches its capacity limit.
///
/// ```swift
/// let cache = LRUCache<String, Data>(capacity: 100)
///
/// await cache.set("key1", value: data1)
/// await cache.set("key2", value: data2)
///
/// // Access key1 - moves it to front
/// let _ = await cache.get("key1")
///
/// // When cache is full, key2 will be evicted first
/// // since key1 was more recently accessed
/// ```
///
/// ## Performance
/// - Get: O(1) average
/// - Set: O(1) average
/// - Remove: O(1) average
///
/// ## Thread Safety
/// All operations are thread-safe via actor isolation.
public actor LRUCache<Key: Hashable & Sendable, Value: Sendable>: CacheProtocol {
    
    // MARK: - Doubly Linked List Node
    
    /// A node in the doubly linked list.
    private final class Node: @unchecked Sendable {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        var expiration: Date?
        var accessCount: Int = 1
        var creationDate: Date = Date()
        
        init(key: Key, value: Value, expiration: Date? = nil) {
            self.key = key
            self.value = value
            self.expiration = expiration
        }
        
        var isExpired: Bool {
            guard let exp = expiration else { return false }
            return Date() > exp
        }
    }
    
    // MARK: - Properties
    
    /// Maximum number of items the cache can hold.
    public let capacity: Int
    
    /// Dictionary for O(1) key lookup.
    private var cache: [Key: Node] = [:]
    
    /// Head of the linked list (most recently used).
    private var head: Node?
    
    /// Tail of the linked list (least recently used).
    private var tail: Node?
    
    /// Cache statistics.
    private var stats = CacheStatistics()
    
    /// Whether to track statistics.
    private let trackStatistics: Bool
    
    /// Default expiration for entries.
    private let defaultExpiration: CacheExpiration
    
    // MARK: - Initialization
    
    /// Creates a new LRU cache with the specified capacity.
    ///
    /// - Parameters:
    ///   - capacity: Maximum number of items. Must be at least 1.
    ///   - trackStatistics: Whether to track cache statistics.
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
    /// Accessing a value moves it to the front of the LRU list.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil` if not found or expired.
    public func get(_ key: Key) async -> Value? {
        guard let node = cache[key] else {
            if trackStatistics { stats.missCount += 1 }
            return nil
        }
        
        // Check expiration
        if node.isExpired {
            await remove(key)
            if trackStatistics {
                stats.missCount += 1
                stats.expirationCount += 1
            }
            return nil
        }
        
        // Move to front (most recently used)
        moveToFront(node)
        node.accessCount += 1
        
        if trackStatistics { stats.hitCount += 1 }
        
        return node.value
    }
    
    /// Stores a value in the cache.
    ///
    /// If the cache is at capacity, the least recently used item is evicted.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - expiration: Optional expiration policy.
    public func set(_ key: Key, value: Value, expiration: CacheExpiration? = nil) async {
        let exp = expiration ?? defaultExpiration
        
        if let existingNode = cache[key] {
            // Update existing
            existingNode.value = value
            existingNode.expiration = exp.expirationDate
            moveToFront(existingNode)
        } else {
            // Add new
            if cache.count >= capacity {
                evictLRU()
            }
            
            let node = Node(key: key, value: value, expiration: exp.expirationDate)
            cache[key] = node
            addToFront(node)
            
            if trackStatistics { stats.itemCount = cache.count }
        }
    }
    
    /// Removes a value from the cache.
    ///
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) async {
        guard let node = cache.removeValue(forKey: key) else { return }
        removeNode(node)
        if trackStatistics { stats.itemCount = cache.count }
    }
    
    /// Removes all values from the cache.
    public func removeAll() async {
        cache.removeAll()
        head = nil
        tail = nil
        if trackStatistics { stats.itemCount = 0 }
    }
    
    /// Checks if a key exists in the cache.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists and is not expired.
    public func contains(_ key: Key) async -> Bool {
        guard let node = cache[key] else { return false }
        return !node.isExpired
    }
    
    /// Returns the number of items currently in the cache.
    public var count: Int {
        cache.count
    }
    
    // MARK: - Extended Operations
    
    /// Peeks at a value without affecting LRU order.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value, or `nil` if not found or expired.
    public func peek(_ key: Key) -> Value? {
        guard let node = cache[key], !node.isExpired else { return nil }
        return node.value
    }
    
    /// Returns the most recently used item.
    public var mostRecentlyUsed: (key: Key, value: Value)? {
        guard let node = head, !node.isExpired else { return nil }
        return (node.key, node.value)
    }
    
    /// Returns the least recently used item.
    public var leastRecentlyUsed: (key: Key, value: Value)? {
        guard let node = tail, !node.isExpired else { return nil }
        return (node.key, node.value)
    }
    
    /// Returns all keys in LRU order (most recent first).
    public var keysInOrder: [Key] {
        var keys: [Key] = []
        var current = head
        while let node = current {
            keys.append(node.key)
            current = node.next
        }
        return keys
    }
    
    /// Removes all expired entries.
    ///
    /// - Returns: Number of entries removed.
    @discardableResult
    public func removeExpired() async -> Int {
        var removed = 0
        var current = head
        
        while let node = current {
            let next = node.next
            if node.isExpired {
                cache.removeValue(forKey: node.key)
                removeNode(node)
                removed += 1
            }
            current = next
        }
        
        if trackStatistics {
            stats.expirationCount += removed
            stats.itemCount = cache.count
        }
        
        return removed
    }
    
    /// Resizes the cache capacity.
    ///
    /// If the new capacity is smaller, excess items are evicted.
    ///
    /// - Parameter newCapacity: The new capacity.
    public func resize(to newCapacity: Int) async {
        precondition(newCapacity > 0, "Capacity must be at least 1")
        
        while cache.count > newCapacity {
            evictLRU()
        }
    }
    
    /// Returns cache statistics.
    public func getStatistics() -> CacheStatistics {
        return stats
    }
    
    /// Resets cache statistics.
    public func resetStatistics() {
        stats.reset()
    }
    
    // MARK: - Private Methods
    
    /// Adds a node to the front of the list.
    private func addToFront(_ node: Node) {
        node.next = head
        node.prev = nil
        
        if let oldHead = head {
            oldHead.prev = node
        }
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    /// Removes a node from the list.
    private func removeNode(_ node: Node) {
        if let prev = node.prev {
            prev.next = node.next
        } else {
            head = node.next
        }
        
        if let next = node.next {
            next.prev = node.prev
        } else {
            tail = node.prev
        }
        
        node.prev = nil
        node.next = nil
    }
    
    /// Moves a node to the front of the list.
    private func moveToFront(_ node: Node) {
        guard node !== head else { return }
        removeNode(node)
        addToFront(node)
    }
    
    /// Evicts the least recently used item.
    private func evictLRU() {
        guard let lru = tail else { return }
        cache.removeValue(forKey: lru.key)
        removeNode(lru)
        
        if trackStatistics {
            stats.evictionCount += 1
            stats.itemCount = cache.count
        }
    }
}

// MARK: - LRU Cache with Cost

/// An LRU cache that also considers item cost for eviction.
///
/// This variant allows assigning a cost to each item and tracks
/// total cost for memory-conscious caching.
public actor LRUCacheWithCost<Key: Hashable & Sendable, Value: Sendable>: CacheProtocol {
    
    private struct Entry: Sendable {
        let value: Value
        let cost: Int
        var expiration: Date?
        var accessTime: Date
        
        var isExpired: Bool {
            guard let exp = expiration else { return false }
            return Date() > exp
        }
    }
    
    public let maxCost: Int
    private var cache: [Key: Entry] = [:]
    private var accessOrder: [Key] = []
    private var currentCost: Int = 0
    
    /// Creates a cache with maximum total cost.
    ///
    /// - Parameter maxCost: Maximum total cost of all items.
    public init(maxCost: Int) {
        precondition(maxCost > 0, "Max cost must be at least 1")
        self.maxCost = maxCost
    }
    
    public func get(_ key: Key) async -> Value? {
        guard let entry = cache[key], !entry.isExpired else { return nil }
        
        // Update access order
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
        
        return entry.value
    }
    
    public func set(_ key: Key, value: Value, expiration: CacheExpiration? = nil) async {
        await set(key, value: value, cost: 1, expiration: expiration)
    }
    
    /// Stores a value with an associated cost.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - cost: The cost of this item.
    ///   - expiration: Optional expiration.
    public func set(_ key: Key, value: Value, cost: Int, expiration: CacheExpiration? = nil) async {
        // Remove existing
        if let existing = cache[key] {
            currentCost -= existing.cost
            accessOrder.removeAll { $0 == key }
        }
        
        // Evict until we have room
        while currentCost + cost > maxCost && !accessOrder.isEmpty {
            let lruKey = accessOrder.removeFirst()
            if let entry = cache.removeValue(forKey: lruKey) {
                currentCost -= entry.cost
            }
        }
        
        let entry = Entry(
            value: value,
            cost: cost,
            expiration: expiration?.expirationDate,
            accessTime: Date()
        )
        cache[key] = entry
        accessOrder.append(key)
        currentCost += cost
    }
    
    public func remove(_ key: Key) async {
        if let entry = cache.removeValue(forKey: key) {
            currentCost -= entry.cost
            accessOrder.removeAll { $0 == key }
        }
    }
    
    public func removeAll() async {
        cache.removeAll()
        accessOrder.removeAll()
        currentCost = 0
    }
    
    public func contains(_ key: Key) async -> Bool {
        guard let entry = cache[key] else { return false }
        return !entry.isExpired
    }
    
    public var count: Int {
        cache.count
    }
    
    /// Returns the current total cost.
    public var totalCost: Int {
        currentCost
    }
}

// WeakCache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Weak Cache

/// A cache that holds weak references to objects.
///
/// `WeakCache` stores weak references to objects, allowing them to be
/// deallocated when no other strong references exist. This is useful
/// for caching objects that should not prevent deallocation.
///
/// ## Overview
/// Use `WeakCache` when you want to cache objects without extending
/// their lifetime.
///
/// ```swift
/// let cache = WeakCache<String, MyObject>()
///
/// autoreleasepool {
///     let obj = MyObject()
///     await cache.set("key", value: obj)
///     // obj is still accessible here
/// }
///
/// // obj has been deallocated, cache returns nil
/// let result = await cache.get("key") // nil
/// ```
///
/// ## Limitations
/// - Only works with class types (reference types)
/// - Values may disappear at any time
/// - Not suitable for value types
public actor WeakCache<Key: Hashable & Sendable, Value: AnyObject & Sendable> {
    
    // MARK: - Weak Box
    
    /// Wrapper holding a weak reference.
    private final class WeakBox<T: AnyObject>: @unchecked Sendable {
        weak var value: T?
        let creationDate: Date
        var expiration: Date?
        
        init(_ value: T, expiration: Date? = nil) {
            self.value = value
            self.creationDate = Date()
            self.expiration = expiration
        }
        
        var isExpired: Bool {
            guard let exp = expiration else { return false }
            return Date() > exp
        }
        
        var isAlive: Bool {
            value != nil && !isExpired
        }
    }
    
    // MARK: - Properties
    
    /// Internal storage.
    private var storage: [Key: WeakBox<Value>] = [:]
    
    /// Maximum number of entries.
    private let capacity: Int?
    
    /// Keys in insertion order.
    private var insertionOrder: [Key] = []
    
    /// Cleanup interval.
    private let cleanupInterval: TimeInterval
    
    /// Cleanup task.
    private var cleanupTask: Task<Void, Never>?
    
    /// Statistics.
    private var stats = CacheStatistics()
    
    // MARK: - Initialization
    
    /// Creates a new weak cache.
    ///
    /// - Parameters:
    ///   - capacity: Optional maximum capacity.
    ///   - cleanupInterval: Interval for removing dead references.
    public init(capacity: Int? = nil, cleanupInterval: TimeInterval = 60) {
        self.capacity = capacity
        self.cleanupInterval = cleanupInterval
        startCleanupTimer()
    }
    
    deinit {
        cleanupTask?.cancel()
    }
    
    // MARK: - Cache Operations
    
    /// Retrieves a value from the cache.
    ///
    /// Returns `nil` if the value has been deallocated or expired.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value, or `nil` if not found or deallocated.
    public func get(_ key: Key) -> Value? {
        guard let box = storage[key] else {
            stats.missCount += 1
            return nil
        }
        
        guard let value = box.value, !box.isExpired else {
            // Clean up dead reference
            storage.removeValue(forKey: key)
            insertionOrder.removeAll { $0 == key }
            stats.missCount += 1
            return nil
        }
        
        stats.hitCount += 1
        return value
    }
    
    /// Stores a weak reference to a value.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store (weak reference).
    ///   - expiration: Optional expiration policy.
    public func set(_ key: Key, value: Value, expiration: CacheExpiration? = nil) {
        // Evict if at capacity
        if let cap = capacity, storage.count >= cap {
            evictOldest()
        }
        
        let box = WeakBox(value, expiration: expiration?.expirationDate)
        
        if storage[key] == nil {
            insertionOrder.append(key)
        }
        
        storage[key] = box
        stats.itemCount = storage.count
    }
    
    /// Removes a reference from the cache.
    ///
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) {
        storage.removeValue(forKey: key)
        insertionOrder.removeAll { $0 == key }
        stats.itemCount = storage.count
    }
    
    /// Removes all references from the cache.
    public func removeAll() {
        storage.removeAll()
        insertionOrder.removeAll()
        stats.itemCount = 0
    }
    
    /// Checks if a key exists and its value is still alive.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the value exists and is alive.
    public func contains(_ key: Key) -> Bool {
        guard let box = storage[key] else { return false }
        return box.isAlive
    }
    
    /// Returns the number of stored references (may include dead ones).
    public var count: Int {
        storage.count
    }
    
    /// Returns the number of live (non-deallocated) entries.
    public var liveCount: Int {
        storage.values.filter { $0.isAlive }.count
    }
    
    // MARK: - Extended Operations
    
    /// Removes all dead (deallocated) references.
    ///
    /// - Returns: Number of dead references removed.
    @discardableResult
    public func compact() -> Int {
        var removed = 0
        var keysToRemove: [Key] = []
        
        for (key, box) in storage where !box.isAlive {
            keysToRemove.append(key)
        }
        
        for key in keysToRemove {
            storage.removeValue(forKey: key)
            insertionOrder.removeAll { $0 == key }
            removed += 1
        }
        
        stats.itemCount = storage.count
        return removed
    }
    
    /// Returns all currently alive keys.
    public var aliveKeys: [Key] {
        storage.filter { $0.value.isAlive }.map { $0.key }
    }
    
    /// Returns cache statistics.
    public func getStatistics() -> CacheStatistics {
        stats
    }
    
    /// Gets or creates a value.
    ///
    /// - Parameters:
    ///   - key: The key to look up or create.
    ///   - creator: Closure to create the value if not found.
    /// - Returns: The existing or newly created value.
    public func getOrCreate(_ key: Key, creator: () -> Value) -> Value {
        if let existing = get(key) {
            return existing
        }
        
        let value = creator()
        set(key, value: value)
        return value
    }
    
    // MARK: - Private Methods
    
    /// Evicts the oldest entry.
    private func evictOldest() {
        guard !insertionOrder.isEmpty else { return }
        let key = insertionOrder.removeFirst()
        storage.removeValue(forKey: key)
        stats.evictionCount += 1
    }
    
    /// Starts the periodic cleanup timer.
    private func startCleanupTimer() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.cleanupInterval ?? 60) * 1_000_000_000)
                _ = await self?.compact()
            }
        }
    }
}

// MARK: - Weak Value Cache

/// A generic weak value cache that works with NSObject types.
public actor WeakValueCache<Key: Hashable & Sendable> {
    
    /// NSMapTable-based storage for weak values.
    private let storage = NSMapTable<AnyObject, AnyObject>.strongToWeakObjects()
    
    /// Key wrapper for NSMapTable.
    private final class KeyWrapper: NSObject {
        let key: AnyHashable
        
        init(_ key: AnyHashable) {
            self.key = key
        }
        
        override var hash: Int {
            key.hashValue
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? KeyWrapper else { return false }
            return key == other.key
        }
    }
    
    private var keyWrappers: [Key: KeyWrapper] = [:]
    
    /// Creates a new weak value cache.
    public init() {}
    
    /// Retrieves a value from the cache.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value, or `nil` if not found or deallocated.
    public func get<Value: AnyObject>(_ key: Key) -> Value? {
        guard let wrapper = keyWrappers[key] else { return nil }
        return storage.object(forKey: wrapper) as? Value
    }
    
    /// Stores a weak reference to a value.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    public func set<Value: AnyObject>(_ key: Key, value: Value) {
        let wrapper = keyWrappers[key] ?? KeyWrapper(key)
        keyWrappers[key] = wrapper
        storage.setObject(value, forKey: wrapper)
    }
    
    /// Removes a value from the cache.
    ///
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) {
        guard let wrapper = keyWrappers.removeValue(forKey: key) else { return }
        storage.removeObject(forKey: wrapper)
    }
    
    /// Removes all values from the cache.
    public func removeAll() {
        storage.removeAllObjects()
        keyWrappers.removeAll()
    }
}

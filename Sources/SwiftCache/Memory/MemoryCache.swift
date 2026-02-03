// MemoryCache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Memory Cache

/// A thread-safe in-memory cache implementation.
///
/// `MemoryCache` provides fast, concurrent access to cached data stored
/// entirely in memory. It supports configurable eviction policies,
/// automatic expiration, and memory pressure handling.
///
/// ## Overview
/// Use `MemoryCache` for caching data that needs quick access and
/// doesn't need to persist across app launches.
///
/// ```swift
/// let cache = MemoryCache<String, User>()
///
/// // Store a user
/// await cache.set("user_123", value: user)
///
/// // Retrieve the user
/// if let user = await cache.get("user_123") {
///     print("Found user: \(user.name)")
/// }
/// ```
///
/// ## Thread Safety
/// All operations are thread-safe and can be called from any thread.
///
/// ## Memory Management
/// The cache automatically responds to memory pressure notifications
/// by evicting items according to the configured policy.
///
/// ## Topics
/// ### Creating a Cache
/// - ``init(configuration:)``
///
/// ### Storing Values
/// - ``set(_:value:expiration:)``
/// - ``set(_:value:expiration:priority:)``
///
/// ### Retrieving Values
/// - ``get(_:)``
/// - ``getWithMetadata(_:)``
///
/// ### Removing Values
/// - ``remove(_:)``
/// - ``removeAll()``
/// - ``removeExpired()``
public actor MemoryCache<Key: Hashable & Sendable, Value: Sendable>: CacheProtocol {
    
    // MARK: - Types
    
    /// Internal storage entry with metadata.
    private struct Entry: Sendable {
        let value: Value
        var metadata: CacheMetadata
        let priority: CachePriority
        
        init(value: Value, expiration: Date?, priority: CachePriority = .normal, sizeInBytes: Int = 0) {
            self.value = value
            self.metadata = CacheMetadata(
                creationDate: Date(),
                lastAccessDate: Date(),
                accessCount: 1,
                sizeInBytes: sizeInBytes,
                expiration: expiration
            )
            self.priority = priority
        }
        
        var isExpired: Bool {
            metadata.isExpired
        }
        
        mutating func recordAccess() {
            metadata.recordAccess()
        }
    }
    
    // MARK: - Properties
    
    /// The cache configuration.
    public let configuration: CacheConfiguration
    
    /// Internal storage dictionary.
    private var storage: [Key: Entry] = [:]
    
    /// Order of keys for FIFO eviction.
    private var insertionOrder: [Key] = []
    
    /// Access order for LRU eviction.
    private var accessOrder: [Key] = []
    
    /// Cache statistics.
    private var stats = CacheStatistics()
    
    /// Observers for cache events.
    private var observers: [CacheObserverWrapper] = []
    
    /// Cleanup task handle.
    private var cleanupTask: Task<Void, Never>?
    
    /// Total bytes currently used.
    private var currentBytes: Int = 0
    
    // MARK: - Initialization
    
    /// Creates a new memory cache with the specified configuration.
    ///
    /// - Parameter configuration: The cache configuration. Defaults to `.default`.
    public init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        startCleanupTimer()
    }
    
    deinit {
        cleanupTask?.cancel()
    }
    
    // MARK: - CacheProtocol Implementation
    
    /// Retrieves a value from the cache.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil` if not found or expired.
    public func get(_ key: Key) async -> Value? {
        guard var entry = storage[key] else {
            if configuration.trackStatistics {
                stats.missCount += 1
            }
            return nil
        }
        
        // Check expiration
        if entry.isExpired {
            if configuration.lazyExpiration {
                storage.removeValue(forKey: key)
                removeFromOrders(key)
                if configuration.trackStatistics {
                    stats.expirationCount += 1
                    stats.itemCount = storage.count
                }
            }
            stats.missCount += 1
            return nil
        }
        
        // Update access tracking
        entry.recordAccess()
        storage[key] = entry
        updateAccessOrder(for: key)
        
        if configuration.trackStatistics {
            stats.hitCount += 1
        }
        
        return entry.value
    }
    
    /// Stores a value in the cache.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - expiration: Optional expiration policy for this entry.
    public func set(_ key: Key, value: Value, expiration: CacheExpiration? = nil) async {
        await set(key, value: value, expiration: expiration, priority: .normal)
    }
    
    /// Stores a value with priority in the cache.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - expiration: Optional expiration policy for this entry.
    ///   - priority: The priority level for this entry.
    public func set(_ key: Key, value: Value, expiration: CacheExpiration?, priority: CachePriority) async {
        let exp = expiration ?? configuration.defaultExpiration
        let expirationDate = exp.expirationDate
        let sizeInBytes = estimateSize(of: value)
        
        // Check if we need to evict
        await evictIfNeeded(requiredBytes: sizeInBytes)
        
        let isUpdate = storage[key] != nil
        
        // Update byte tracking
        if let existingEntry = storage[key] {
            currentBytes -= existingEntry.metadata.sizeInBytes
        }
        currentBytes += sizeInBytes
        
        // Store the entry
        let entry = Entry(
            value: value,
            expiration: expirationDate,
            priority: priority,
            sizeInBytes: sizeInBytes
        )
        storage[key] = entry
        
        // Update order tracking
        if !isUpdate {
            insertionOrder.append(key)
        }
        updateAccessOrder(for: key)
        
        // Update statistics
        if configuration.trackStatistics {
            stats.itemCount = storage.count
            stats.totalBytes = currentBytes
        }
        
        // Notify observers
        if configuration.notifyObservers {
            let event: CacheEvent = isUpdate ? .updated(key: "\(key)") : .added(key: "\(key)")
            notifyObservers(event: event)
        }
    }
    
    /// Removes a value from the cache.
    ///
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) async {
        guard let entry = storage.removeValue(forKey: key) else { return }
        
        removeFromOrders(key)
        currentBytes -= entry.metadata.sizeInBytes
        
        if configuration.trackStatistics {
            stats.itemCount = storage.count
            stats.totalBytes = currentBytes
        }
        
        if configuration.notifyObservers {
            notifyObservers(event: .removed(key: "\(key)"))
        }
    }
    
    /// Removes all values from the cache.
    public func removeAll() async {
        storage.removeAll()
        insertionOrder.removeAll()
        accessOrder.removeAll()
        currentBytes = 0
        
        if configuration.trackStatistics {
            stats.itemCount = 0
            stats.totalBytes = 0
        }
        
        if configuration.notifyObservers {
            notifyObservers(event: .cleared)
        }
    }
    
    /// Checks if a key exists in the cache.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists and is not expired.
    public func contains(_ key: Key) async -> Bool {
        guard let entry = storage[key] else { return false }
        return !entry.isExpired
    }
    
    /// Returns the number of items currently in the cache.
    public var count: Int {
        storage.count
    }
    
    // MARK: - Extended Operations
    
    /// Retrieves a value with its metadata.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: A tuple of the value and its metadata, or `nil` if not found.
    public func getWithMetadata(_ key: Key) -> (Value, CacheMetadata)? {
        guard var entry = storage[key], !entry.isExpired else { return nil }
        entry.recordAccess()
        storage[key] = entry
        return (entry.value, entry.metadata)
    }
    
    /// Removes all expired entries from the cache.
    ///
    /// - Returns: The number of entries removed.
    @discardableResult
    public func removeExpired() -> Int {
        var removedCount = 0
        
        for (key, entry) in storage where entry.isExpired {
            storage.removeValue(forKey: key)
            removeFromOrders(key)
            currentBytes -= entry.metadata.sizeInBytes
            removedCount += 1
        }
        
        if configuration.trackStatistics {
            stats.expirationCount += removedCount
            stats.itemCount = storage.count
            stats.totalBytes = currentBytes
        }
        
        return removedCount
    }
    
    /// Returns all keys currently in the cache.
    public var keys: [Key] {
        Array(storage.keys)
    }
    
    /// Returns all values currently in the cache.
    public var values: [Value] {
        storage.values.map { $0.value }
    }
    
    /// Returns the current cache statistics.
    public func getStatistics() -> CacheStatistics {
        return stats
    }
    
    /// Resets cache statistics.
    public func resetStatistics() {
        stats.reset()
    }
    
    /// Updates the expiration for an existing entry.
    ///
    /// - Parameters:
    ///   - key: The key to update.
    ///   - expiration: The new expiration policy.
    /// - Returns: `true` if the entry was updated.
    @discardableResult
    public func updateExpiration(_ key: Key, expiration: CacheExpiration) -> Bool {
        guard var entry = storage[key] else { return false }
        entry.metadata.expiration = expiration.expirationDate
        storage[key] = entry
        return true
    }
    
    // MARK: - Observer Management
    
    /// Adds an observer for cache events.
    ///
    /// - Parameter observer: The observer to add.
    /// - Returns: A token that can be used to remove the observer.
    @discardableResult
    public func addObserver(_ observer: any CacheObserver) -> ObserverToken {
        let wrapper = CacheObserverWrapper(observer: observer)
        observers.append(wrapper)
        return ObserverToken(id: wrapper.id)
    }
    
    /// Removes an observer.
    ///
    /// - Parameter token: The token returned when the observer was added.
    public func removeObserver(_ token: ObserverToken) {
        observers.removeAll { $0.id == token.id }
    }
    
    // MARK: - Private Methods
    
    /// Estimates the size of a value in bytes.
    private func estimateSize(of value: Value) -> Int {
        // Rough estimation - can be overridden for specific types
        return MemoryLayout<Value>.size
    }
    
    /// Updates the access order for LRU tracking.
    private func updateAccessOrder(for key: Key) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }
    
    /// Removes a key from order tracking arrays.
    private func removeFromOrders(_ key: Key) {
        if let index = insertionOrder.firstIndex(of: key) {
            insertionOrder.remove(at: index)
        }
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }
    
    /// Evicts items if the cache is full.
    private func evictIfNeeded(requiredBytes: Int = 0) async {
        // Check item count limit
        if let maxItems = configuration.maxItemCount, storage.count >= maxItems {
            await evictItems(count: 1)
        }
        
        // Check memory limit
        if let maxBytes = configuration.maxMemoryBytes, currentBytes + requiredBytes > maxBytes {
            let bytesToFree = currentBytes + requiredBytes - maxBytes
            await evictBySize(bytesToFree: bytesToFree)
        }
    }
    
    /// Evicts a specified number of items.
    private func evictItems(count: Int) async {
        let keysToEvict = selectKeysForEviction(count: count)
        
        for key in keysToEvict {
            if let entry = storage.removeValue(forKey: key) {
                removeFromOrders(key)
                currentBytes -= entry.metadata.sizeInBytes
                
                if configuration.trackStatistics {
                    stats.evictionCount += 1
                }
                
                if configuration.notifyObservers {
                    notifyObservers(event: .evicted(key: "\(key)", reason: .capacityLimit))
                }
            }
        }
        
        if configuration.trackStatistics {
            stats.itemCount = storage.count
            stats.totalBytes = currentBytes
        }
    }
    
    /// Evicts items until the specified bytes are freed.
    private func evictBySize(bytesToFree: Int) async {
        var freedBytes = 0
        
        while freedBytes < bytesToFree && !storage.isEmpty {
            guard let keyToEvict = selectKeysForEviction(count: 1).first else { break }
            
            if let entry = storage.removeValue(forKey: keyToEvict) {
                removeFromOrders(keyToEvict)
                freedBytes += entry.metadata.sizeInBytes
                currentBytes -= entry.metadata.sizeInBytes
                
                if configuration.trackStatistics {
                    stats.evictionCount += 1
                }
            }
        }
        
        if configuration.trackStatistics {
            stats.itemCount = storage.count
            stats.totalBytes = currentBytes
        }
    }
    
    /// Selects keys for eviction based on the configured policy.
    private func selectKeysForEviction(count: Int) -> [Key] {
        // Filter out critical priority items
        let evictableKeys = storage.filter { $0.value.priority != .critical }.map { $0.key }
        
        guard !evictableKeys.isEmpty else { return [] }
        
        switch configuration.evictionPolicy {
        case .lru:
            return Array(accessOrder.filter { evictableKeys.contains($0) }.prefix(count))
            
        case .fifo:
            return Array(insertionOrder.filter { evictableKeys.contains($0) }.prefix(count))
            
        case .lfu:
            let sorted = storage
                .filter { evictableKeys.contains($0.key) }
                .sorted { $0.value.metadata.accessCount < $1.value.metadata.accessCount }
            return Array(sorted.prefix(count).map { $0.key })
            
        case .ttl:
            let sorted = storage
                .filter { evictableKeys.contains($0.key) && $0.value.metadata.expiration != nil }
                .sorted { ($0.value.metadata.expiration ?? .distantFuture) < ($1.value.metadata.expiration ?? .distantFuture) }
            return Array(sorted.prefix(count).map { $0.key })
            
        case .random:
            return Array(evictableKeys.shuffled().prefix(count))
            
        case .size:
            let sorted = storage
                .filter { evictableKeys.contains($0.key) }
                .sorted { $0.value.metadata.sizeInBytes > $1.value.metadata.sizeInBytes }
            return Array(sorted.prefix(count).map { $0.key })
        }
    }
    
    /// Starts the periodic cleanup timer.
    private func startCleanupTimer() {
        guard let interval = configuration.cleanupInterval else { return }
        
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await self?.removeExpired()
            }
        }
    }
    
    /// Notifies all observers of an event.
    private func notifyObservers(event: CacheEvent) {
        for observer in observers {
            observer.observer.cacheDidChange(event: event)
        }
    }
}

// MARK: - Observer Wrapper

/// Internal wrapper for cache observers.
private struct CacheObserverWrapper: Sendable {
    let id: UUID
    let observer: any CacheObserver
    
    init(observer: any CacheObserver) {
        self.id = UUID()
        self.observer = observer
    }
}

// MARK: - Observer Token

/// Token returned when adding an observer.
public struct ObserverToken: Sendable, Equatable {
    let id: UUID
}

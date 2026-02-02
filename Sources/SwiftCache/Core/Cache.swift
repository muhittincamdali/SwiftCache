import Foundation

// MARK: - CacheProtocol

/// Protocol defining the fundamental cache operations.
///
/// Conforming types provide key-value storage with support for
/// time-to-live expiration and bulk operations.
public protocol CacheProtocol: Actor {
    /// The type used for cache keys.
    associatedtype Key: Hashable & Sendable
    /// The type used for cached values.
    associatedtype Value: Sendable

    /// Retrieves a value from the cache.
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil` if not found or expired.
    func get(_ key: Key) async throws -> Value?

    /// Stores a value in the cache.
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The key to associate with the value.
    ///   - ttl: Optional time-to-live override. Uses default if `nil`.
    func set(_ value: Value, forKey key: Key, ttl: TimeInterval?) async throws

    /// Removes a value from the cache.
    /// - Parameter key: The key to remove.
    func remove(_ key: Key) async throws

    /// Removes all values from the cache.
    func removeAll() async throws

    /// Checks whether the cache contains a value for the given key.
    /// - Parameter key: The key to check.
    /// - Returns: `true` if a non-expired value exists.
    func contains(_ key: Key) async throws -> Bool

    /// Returns the number of items currently in the cache.
    var count: Int { get async }
}

// MARK: - Cache

/// A high-performance, generic, multi-layer caching system.
///
/// `Cache` provides a unified interface for storing and retrieving values
/// through a configurable pipeline of cache layers. It supports memory,
/// disk, and network layers with automatic promotion and demotion.
///
/// ## Usage
///
/// ```swift
/// let cache = Cache<String, Data>(configuration: .default)
/// try await cache.set(imageData, forKey: "avatar")
/// let data = try await cache.get("avatar")
/// ```
///
/// ## Architecture
///
/// The cache uses a pipeline architecture where each layer is checked
/// in order. When a value is found in a lower layer, it is automatically
/// promoted to higher layers for faster subsequent access.
public actor Cache<Key: Hashable & Sendable & Codable, Value: Sendable & Codable> {

    // MARK: - Properties

    /// The configuration governing cache behavior.
    public let configuration: CacheConfiguration

    /// The cache pipeline managing multi-layer storage.
    private let pipeline: CachePipeline<Key, Value>

    /// Monitor for tracking cache metrics.
    private let monitor: CacheMonitor

    /// Internal storage for direct access patterns.
    private var storage: [Key: CacheEntry<Value>] = [:]

    /// Access order tracking for eviction policies.
    private var accessOrder: [Key] = []

    /// Frequency counter for LFU policy.
    private var frequencyMap: [Key: Int] = [:]

    /// Insertion order tracking for FIFO policy.
    private var insertionOrder: [Key] = []

    /// Timer for periodic cleanup of expired entries.
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new cache with the specified configuration.
    /// - Parameter configuration: The configuration to use. Defaults to `.default`.
    public init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        self.monitor = CacheMonitor()
        self.pipeline = CachePipeline(configuration: configuration)
        startPeriodicCleanup()
    }

    deinit {
        cleanupTask?.cancel()
    }

    // MARK: - Public API

    /// Retrieves a value from the cache for the given key.
    ///
    /// Checks each layer in the pipeline sequentially. If found in a lower
    /// layer, the value is promoted to higher layers automatically.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil` if not found or expired.
    public func get(_ key: Key) async throws -> Value? {
        if let entry = storage[key] {
            guard !entry.isExpired else {
                storage.removeValue(forKey: key)
                accessOrder.removeAll { $0 == key }
                frequencyMap.removeValue(forKey: key)
                insertionOrder.removeAll { $0 == key }
                await monitor.recordMiss()
                return nil
            }
            updateAccessOrder(for: key)
            await monitor.recordHit()
            return entry.value
        }

        // Check pipeline layers
        if let value = try await pipeline.get(key) {
            let entry = CacheEntry(
                value: value,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(configuration.defaultTTL),
                metadata: EntryMetadata()
            )
            storage[key] = entry
            trackInsertion(of: key)
            await monitor.recordHit()
            return value
        }

        await monitor.recordMiss()
        return nil
    }

    /// Stores a value in the cache.
    ///
    /// The value is stored in all layers of the pipeline simultaneously.
    /// If the cache is at capacity, the eviction policy determines which
    /// entry is removed.
    ///
    /// - Parameters:
    ///   - value: The value to cache.
    ///   - key: The key to associate with the value.
    ///   - ttl: Optional TTL override in seconds. Uses default if `nil`.
    public func set(_ value: Value, forKey key: Key, ttl: TimeInterval? = nil) async throws {
        let effectiveTTL = ttl ?? configuration.defaultTTL
        let entry = CacheEntry(
            value: value,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(effectiveTTL),
            metadata: EntryMetadata()
        )

        // Evict if necessary
        if storage.count >= configuration.maxEntryCount && storage[key] == nil {
            evictEntry()
        }

        storage[key] = entry
        trackInsertion(of: key)

        // Propagate to pipeline layers
        try await pipeline.set(value, forKey: key, ttl: effectiveTTL)
        await monitor.recordWrite()
    }

    /// Removes a value from all cache layers.
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) async throws {
        storage.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
        frequencyMap.removeValue(forKey: key)
        insertionOrder.removeAll { $0 == key }
        try await pipeline.remove(key)
        await monitor.recordEviction()
    }

    /// Clears all entries from every cache layer.
    public func removeAll() async throws {
        storage.removeAll()
        accessOrder.removeAll()
        frequencyMap.removeAll()
        insertionOrder.removeAll()
        try await pipeline.removeAll()
    }

    /// Checks whether a non-expired value exists for the key.
    /// - Parameter key: The key to check.
    /// - Returns: `true` if a valid entry exists.
    public func contains(_ key: Key) async throws -> Bool {
        if let entry = storage[key] {
            return !entry.isExpired
        }
        return try await pipeline.contains(key)
    }

    /// The number of entries currently stored in the primary layer.
    public var count: Int {
        storage.count
    }

    /// Returns a snapshot of the current cache metrics.
    public func metrics() async -> CacheMetrics {
        await monitor.snapshot()
    }

    /// Performs a manual cleanup of expired entries.
    public func purgeExpired() async throws {
        let expiredKeys = storage.filter { $0.value.isExpired }.map(\.key)
        for key in expiredKeys {
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            frequencyMap.removeValue(forKey: key)
            insertionOrder.removeAll { $0 == key }
        }
        try await pipeline.purgeExpired()
    }

    // MARK: - Subscript

    /// Subscript access for cache values.
    ///
    /// Note: This only checks the in-memory layer synchronously.
    public subscript(key: Key) -> Value? {
        storage[key]?.isExpired == false ? storage[key]?.value : nil
    }

    // MARK: - Private Methods

    /// Updates access tracking for the given key based on the eviction policy.
    private func updateAccessOrder(for key: Key) {
        switch configuration.evictionPolicy {
        case .lru:
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
        case .lfu:
            frequencyMap[key, default: 0] += 1
        case .fifo, .ttl:
            break
        }
    }

    /// Records a new insertion for eviction tracking.
    private func trackInsertion(of key: Key) {
        switch configuration.evictionPolicy {
        case .lru:
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
        case .lfu:
            frequencyMap[key, default: 0] += 1
        case .fifo:
            if !insertionOrder.contains(key) {
                insertionOrder.append(key)
            }
        case .ttl:
            break
        }
    }

    /// Evicts a single entry according to the configured policy.
    private func evictEntry() {
        let keyToRemove: Key?

        switch configuration.evictionPolicy {
        case .lru:
            keyToRemove = accessOrder.first
            if let key = keyToRemove {
                accessOrder.removeFirst()
            }
        case .lfu:
            keyToRemove = frequencyMap.min(by: { $0.value < $1.value })?.key
            if let key = keyToRemove {
                frequencyMap.removeValue(forKey: key)
            }
        case .fifo:
            keyToRemove = insertionOrder.first
            if let key = keyToRemove {
                insertionOrder.removeFirst()
            }
        case .ttl:
            keyToRemove = storage
                .filter { $0.value.expiresAt != nil }
                .min(by: { ($0.value.expiresAt ?? .distantFuture) < ($1.value.expiresAt ?? .distantFuture) })?
                .key
        }

        if let key = keyToRemove {
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            frequencyMap.removeValue(forKey: key)
            insertionOrder.removeAll { $0 == key }
        }
    }

    /// Starts a background task that periodically purges expired entries.
    private func startPeriodicCleanup() {
        guard configuration.cleanupInterval > 0 else { return }
        cleanupTask = Task { [weak self, configuration] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(configuration.cleanupInterval * 1_000_000_000))
                try? await self?.purgeExpired()
            }
        }
    }
}

// MARK: - Convenience Extensions

extension Cache where Key == String {
    /// Retrieves a value using a string literal key.
    /// - Parameter key: The string key.
    /// - Returns: The cached value or `nil`.
    public func value(for key: String) async throws -> Value? {
        try await get(key)
    }

    /// Stores a value with a string literal key and optional TTL.
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The string key.
    ///   - ttl: Optional TTL in seconds.
    public func store(_ value: Value, as key: String, ttl: TimeInterval? = nil) async throws {
        try await set(value, forKey: key, ttl: ttl)
    }
}

extension Cache {
    /// Retrieves a value or computes it if not cached.
    ///
    /// This is useful for cache-aside patterns where you want to
    /// populate the cache on a miss.
    ///
    /// - Parameters:
    ///   - key: The cache key.
    ///   - ttl: Optional TTL for the computed value.
    ///   - compute: A closure that produces the value on a cache miss.
    /// - Returns: The cached or freshly computed value.
    public func getOrSet(
        _ key: Key,
        ttl: TimeInterval? = nil,
        compute: () async throws -> Value
    ) async throws -> Value {
        if let existing = try await get(key) {
            return existing
        }
        let value = try await compute()
        try await set(value, forKey: key, ttl: ttl)
        return value
    }
}

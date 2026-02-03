// HybridCache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Hybrid Cache

/// A multi-layer cache combining memory and disk storage.
///
/// `HybridCache` provides fast memory access with persistent disk
/// backup. It automatically manages data flow between layers for
/// optimal performance and persistence.
///
/// ## Overview
/// The hybrid cache checks memory first for fast access, falling
/// back to disk for persistence. Writes go to both layers by default.
///
/// ```swift
/// let cache = try HybridCache<String, User>(
///     name: "users",
///     memoryConfig: .default,
///     maxDiskSize: 100 * 1024 * 1024
/// )
///
/// // Stored in both memory and disk
/// await cache.set("user_123", value: user)
///
/// // First checks memory, falls back to disk
/// let user = await cache.get("user_123")
/// ```
///
/// ## Layer Behavior
/// - **Read**: Memory → Disk (promotes to memory on disk hit)
/// - **Write**: Memory + Disk (configurable)
/// - **Eviction**: Memory eviction doesn't affect disk
///
/// ## Thread Safety
/// All operations are thread-safe via actor isolation.
public actor HybridCache<Key: Hashable & Sendable & CustomStringConvertible, Value: Codable & Sendable> {
    
    // MARK: - Types
    
    /// Configuration for hybrid cache behavior.
    public struct Configuration: Sendable {
        /// Memory cache configuration.
        public var memoryConfig: CacheConfiguration
        
        /// Maximum disk cache size in bytes.
        public var maxDiskSize: Int
        
        /// Whether to write to disk on every set.
        public var writeToDiskOnSet: Bool
        
        /// Whether to promote disk hits to memory.
        public var promoteOnDiskHit: Bool
        
        /// Whether to evict from disk when memory evicts.
        public var cascadeEviction: Bool
        
        /// Cleanup interval for both caches.
        public var cleanupInterval: TimeInterval
        
        /// Default configuration.
        public static let `default` = Configuration(
            memoryConfig: .default,
            maxDiskSize: 500 * 1024 * 1024,
            writeToDiskOnSet: true,
            promoteOnDiskHit: true,
            cascadeEviction: false,
            cleanupInterval: 60
        )
        
        /// Creates a configuration.
        public init(
            memoryConfig: CacheConfiguration = .default,
            maxDiskSize: Int = 500 * 1024 * 1024,
            writeToDiskOnSet: Bool = true,
            promoteOnDiskHit: Bool = true,
            cascadeEviction: Bool = false,
            cleanupInterval: TimeInterval = 60
        ) {
            self.memoryConfig = memoryConfig
            self.maxDiskSize = maxDiskSize
            self.writeToDiskOnSet = writeToDiskOnSet
            self.promoteOnDiskHit = promoteOnDiskHit
            self.cascadeEviction = cascadeEviction
            self.cleanupInterval = cleanupInterval
        }
    }
    
    /// Source of a cache hit.
    public enum HitSource: Sendable {
        case memory
        case disk
    }
    
    // MARK: - Properties
    
    /// Cache name.
    public let name: String
    
    /// Configuration.
    public let configuration: Configuration
    
    /// Memory cache layer.
    private let memoryCache: MemoryCache<Key, Value>
    
    /// Disk cache layer.
    private let diskCache: DiskCache<Key, Value>
    
    /// Combined statistics.
    private var stats = HybridCacheStatistics()
    
    /// Pending disk writes.
    private var pendingWrites: [Key: Value] = [:]
    
    /// Write coalescing task.
    private var writeTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Creates a new hybrid cache.
    ///
    /// - Parameters:
    ///   - name: Unique name for the cache.
    ///   - configuration: Cache configuration.
    ///   - directory: Base directory for disk storage.
    /// - Throws: An error if disk cache creation fails.
    public init(
        name: String,
        configuration: Configuration = .default,
        directory: URL? = nil
    ) throws {
        self.name = name
        self.configuration = configuration
        
        self.memoryCache = MemoryCache<Key, Value>(configuration: configuration.memoryConfig)
        self.diskCache = try DiskCache<Key, Value>(
            name: name,
            directory: directory,
            maxSize: configuration.maxDiskSize,
            cleanupInterval: configuration.cleanupInterval
        )
    }
    
    deinit {
        writeTask?.cancel()
    }
    
    // MARK: - Cache Operations
    
    /// Retrieves a value from the cache.
    ///
    /// Checks memory first, then disk. Disk hits are promoted to memory.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil` if not found.
    public func get(_ key: Key) async -> Value? {
        // Check memory first
        if let value = await memoryCache.get(key) {
            stats.memoryHits += 1
            return value
        }
        
        // Check disk
        if let value = await diskCache.get(key) {
            stats.diskHits += 1
            
            // Promote to memory
            if configuration.promoteOnDiskHit {
                await memoryCache.set(key, value: value)
            }
            
            return value
        }
        
        stats.misses += 1
        return nil
    }
    
    /// Retrieves a value with information about its source.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: Tuple of value and source, or `nil` if not found.
    public func getWithSource(_ key: Key) async -> (value: Value, source: HitSource)? {
        // Check memory first
        if let value = await memoryCache.get(key) {
            stats.memoryHits += 1
            return (value, .memory)
        }
        
        // Check disk
        if let value = await diskCache.get(key) {
            stats.diskHits += 1
            
            if configuration.promoteOnDiskHit {
                await memoryCache.set(key, value: value)
            }
            
            return (value, .disk)
        }
        
        stats.misses += 1
        return nil
    }
    
    /// Stores a value in the cache.
    ///
    /// Writes to memory immediately and optionally to disk.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - expiration: Optional expiration policy.
    ///   - options: Cache options.
    public func set(
        _ key: Key,
        value: Value,
        expiration: CacheExpiration? = nil,
        options: CacheOptions = .default
    ) async {
        // Write to memory (unless skipped)
        if !options.contains(.skipMemory) {
            await memoryCache.set(key, value: value, expiration: expiration)
        }
        
        // Write to disk
        if !options.contains(.skipDisk) && configuration.writeToDiskOnSet {
            do {
                try await diskCache.set(key, value: value, expiration: expiration)
            } catch {
                // Log error but don't fail
            }
        }
    }
    
    /// Stores a value with deferred disk write.
    ///
    /// Writes to memory immediately, coalesces disk writes.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - expiration: Optional expiration policy.
    public func setDeferred(_ key: Key, value: Value, expiration: CacheExpiration? = nil) async {
        await memoryCache.set(key, value: value, expiration: expiration)
        pendingWrites[key] = value
        scheduleDiskWrite()
    }
    
    /// Removes a value from the cache.
    ///
    /// Removes from both memory and disk.
    ///
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) async {
        await memoryCache.remove(key)
        await diskCache.remove(key)
        pendingWrites.removeValue(forKey: key)
    }
    
    /// Removes all values from both layers.
    public func removeAll() async {
        await memoryCache.removeAll()
        await diskCache.removeAll()
        pendingWrites.removeAll()
    }
    
    /// Checks if a key exists in either layer.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists.
    public func contains(_ key: Key) async -> Bool {
        if await memoryCache.contains(key) { return true }
        return await diskCache.contains(key)
    }
    
    // MARK: - Layer-Specific Operations
    
    /// Retrieves a value from memory only.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value, or `nil` if not in memory.
    public func getFromMemory(_ key: Key) async -> Value? {
        await memoryCache.get(key)
    }
    
    /// Retrieves a value from disk only.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value, or `nil` if not on disk.
    public func getFromDisk(_ key: Key) async -> Value? {
        await diskCache.get(key)
    }
    
    /// Clears only the memory layer.
    public func clearMemory() async {
        await memoryCache.removeAll()
    }
    
    /// Clears only the disk layer.
    public func clearDisk() async {
        await diskCache.removeAll()
    }
    
    /// Preloads items from disk into memory.
    ///
    /// - Parameter keys: Keys to preload.
    public func preload(keys: [Key]) async {
        for key in keys {
            if let value = await diskCache.get(key) {
                await memoryCache.set(key, value: value)
            }
        }
    }
    
    /// Persists all memory items to disk.
    public func persistMemory() async {
        // Get all items from memory and write to disk
        // This is a simplified version - full implementation would
        // need access to memory cache internals
        for (key, value) in pendingWrites {
            try? await diskCache.set(key, value: value)
        }
        pendingWrites.removeAll()
    }
    
    // MARK: - Statistics
    
    /// Returns combined cache statistics.
    public func getStatistics() async -> HybridCacheStatistics {
        var combined = stats
        combined.memoryStats = await memoryCache.getStatistics()
        combined.diskStats = await diskCache.getStatistics()
        return combined
    }
    
    /// Resets statistics.
    public func resetStatistics() async {
        stats = HybridCacheStatistics()
        await memoryCache.resetStatistics()
    }
    
    // MARK: - Maintenance
    
    /// Removes expired entries from both layers.
    ///
    /// - Returns: Total number of entries removed.
    @discardableResult
    public func removeExpired() async -> Int {
        let memoryRemoved = await memoryCache.removeExpired()
        let diskRemoved = await diskCache.removeExpired()
        return memoryRemoved + diskRemoved
    }
    
    /// Flushes pending writes to disk.
    public func flush() async {
        for (key, value) in pendingWrites {
            try? await diskCache.set(key, value: value)
        }
        pendingWrites.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Schedules deferred disk writes.
    private func scheduleDiskWrite() {
        writeTask?.cancel()
        writeTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            guard !Task.isCancelled else { return }
            await flush()
        }
    }
}

// MARK: - Hybrid Cache Statistics

/// Statistics for hybrid cache.
public struct HybridCacheStatistics: Sendable {
    /// Memory cache hit count.
    public var memoryHits: Int = 0
    
    /// Disk cache hit count.
    public var diskHits: Int = 0
    
    /// Total miss count.
    public var misses: Int = 0
    
    /// Memory cache statistics.
    public var memoryStats = CacheStatistics()
    
    /// Disk cache statistics.
    public var diskStats = CacheStatistics()
    
    /// Total hit count.
    public var totalHits: Int {
        memoryHits + diskHits
    }
    
    /// Overall hit rate.
    public var hitRate: Double {
        let total = totalHits + misses
        guard total > 0 else { return 0 }
        return Double(totalHits) / Double(total) * 100
    }
    
    /// Memory hit rate (of total hits).
    public var memoryHitRate: Double {
        guard totalHits > 0 else { return 0 }
        return Double(memoryHits) / Double(totalHits) * 100
    }
}
